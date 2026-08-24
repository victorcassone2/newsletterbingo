# One Stripe subscription per account: quantity = billable (non-complimentary)
# publications, $29 per unit. The card goes on file up front and Stripe runs a
# 30-day trial (one full game arc plus a week of runway) before the first
# charge; a restart pays from day one. Status lives in local columns synced
# from webhooks and the checkout return page -- request paths never call
# Stripe to answer "is this account paid?".
#
# Lapsing is gentle by design: gating acts at game-rotation time only, so a
# running game always plays out to its natural end. Readers are never
# punished mid-game; the next game simply doesn't start.
module Account::Billable
  extend ActiveSupport::Concern

  PRICE_PER_PUBLICATION = 29
  TRIAL_LENGTH = 30.days

  # Stripe statuses that count as subscribed. trialing is the card-upfront
  # trial; past_due rides Stripe's retry cycle as a grace period;
  # canceled/unpaid lapse back to unpaid.
  SUBSCRIBED_STATUSES = %w[ active trialing past_due ].freeze

  def subscribed?
    subscription_status.in?(SUBSCRIBED_STATUSES)
  end

  def trialing?
    subscription_status == "trialing"
  end

  # An in-app cancellation is pending: paid through the period end, then
  # Stripe deletes the subscription and the deleted webhook downgrades us.
  def cancel_scheduled?
    subscription_cancel_at_period_end?
  end

  # The only three billing situations a customer is ever shown. How an
  # account became inactive (never subscribed, canceled, checkout abandoned)
  # doesn't change what they see or what fixes it.
  def billing_state
    if subscription_status == "past_due"
      :payment_problem
    elsif subscribed?
      :active
    else
      :inactive
    end
  end

  # The publications the subscription charges for; complimentary ones ride free.
  def billable_publications
    publications.where(complimentary: false)
  end

  def monthly_price
    billable_publications.count * PRICE_PER_PUBLICATION
  end

  # The full trial for a first subscription; a restart pays from day one.
  # The subscription id survives cancellation exactly so this can tell the
  # two apart.
  def stripe_trial_params
    if stripe_subscription_id.blank?
      { trial_period_days: TRIAL_LENGTH.in_days.to_i }
    else
      {}
    end
  end

  # The quantity a subscription created right now should carry. At least 1:
  # a subscription can start before its first publication exists.
  def subscription_quantity
    [ billable_publications.count, 1 ].max
  end

  def start_subscription!(payment_method)
    subscription = Payments.platform.create_subscription(
      customer: stripe_customer_id,
      items: [ { price: Payments.price_id, quantity: subscription_quantity } ],
      default_payment_method: payment_method.id,
      metadata: { account_id: id },
      **stripe_trial_params
    )
    sync_stripe_subscription!(subscription)
    subscription
  end

  # Copy status + renewal date from a Stripe::Subscription. Called from
  # subscription creation, the checkout return page, and the
  # customer.subscription.* webhooks, whichever lands first -- belt and
  # suspenders.
  def sync_stripe_subscription!(subscription)
    transaction do
      update!(
        stripe_subscription_id: subscription.id,
        subscription_status: subscription.status,
        subscription_current_period_end: period_end_from(subscription),
        subscription_cancel_at_period_end: subscription.try(:cancel_at_period_end) || false
      )
      customer_id = customer_id_from(subscription)
      if customer_id.present? && stripe_customer_id.blank?
        update!(stripe_customer_id: customer_id)
      end
    end
  end

  # Re-point the subscription's quantity at the billable publication count
  # (Stripe prorates the difference). Publications enqueue this after
  # create/destroy/complimentary changes.
  def sync_subscription_quantity_later
    Account::SyncSubscriptionQuantityJob.perform_later(self)
  end

  def sync_subscription_quantity!
    return if stripe_subscription_id.blank? || !subscribed?
    quantity = billable_publications.count
    return if quantity.zero?

    subscription = Payments.platform.retrieve_subscription(stripe_subscription_id)
    item = subscription.items.data.first
    if item.try(:quantity) != quantity
      updated = Payments.platform.update_subscription(
        stripe_subscription_id,
        items: [ { id: item.id, quantity: quantity } ]
      )
      sync_stripe_subscription!(updated)
    end
  end

  # The card a subscription would charge: the customer's chosen default, else
  # the card Checkout attached. nil means hosted Checkout must collect one.
  # This is a live Stripe lookup -- admin-time only, never a reader path --
  # and it fails open to Checkout on any Stripe hiccup.
  def stripe_payment_method
    return nil if stripe_customer_id.blank?

    customer = Payments.platform.retrieve_customer(stripe_customer_id)
    default_id = customer.try(:invoice_settings)&.try(:default_payment_method)
    methods = Payments.platform.list_payment_methods(stripe_customer_id).data
    methods.find { |method| method.id == default_id } || methods.first
  rescue Stripe::StripeError
    nil
  end

  # Find-or-create the account's one Stripe Customer.
  def ensure_stripe_customer!
    return stripe_customer_id if stripe_customer_id.present?

    customer = Payments.platform.create_customer(
      email: owners.first&.email_address,
      name: name,
      metadata: { account_id: id }
    )
    update!(stripe_customer_id: customer.id)
    customer.id
  end

  private
    # subscription.customer is usually the id string, but arrives expanded as
    # a full object on some retrievals -- normalize to the id either way.
    def customer_id_from(subscription)
      customer = subscription.try(:customer)
      customer.respond_to?(:id) ? customer.id : customer
    end

    # Stripe moved current_period_end from the subscription's top level to its
    # items in the 2025-03-31.basil API release. Webhook payloads arrive at
    # the endpoint's (newer) version, API retrievals at the gem's (older)
    # pinned version -- accept either shape.
    def period_end_from(subscription)
      period_end = subscription.try(:current_period_end) ||
        subscription.try(:items)&.try(:data)&.first&.try(:current_period_end)
      period_end && Time.zone.at(period_end)
    end
end
