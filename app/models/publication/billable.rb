# Each publication carries its own $29/month Stripe subscription, billed to
# the account's one Stripe Customer. Billing starts at newsletter creation:
# the card goes on file up front and Stripe runs a 30-day trial (one full
# game arc) before the first charge. Status lives in local columns synced
# from webhooks and the checkout return page -- request paths never call
# Stripe to answer "is this publication paid?".
#
# Publications created before card-upfront billing carry an app-side
# trial_ends_at instead; in_trial? keeps them running until they confirm.
#
# Lapsing is gentle by design: gating acts at game-rotation time only, so a
# running game always plays out to its natural end. Readers are never
# punished mid-game; the next game simply doesn't start.
module Publication::Billable
  extend ActiveSupport::Concern

  # One full game arc (24 days) plus a week of runway before the first charge.
  TRIAL_LENGTH = 30.days

  # Stripe statuses that count as subscribed. trialing is the card-upfront
  # trial; past_due rides Stripe's retry cycle as a grace period;
  # canceled/unpaid lapse back to unpaid.
  SUBSCRIBED_STATUSES = %w[ active trialing past_due ].freeze

  def subscribed?
    subscription_status.in?(SUBSCRIBED_STATUSES)
  end

  # The legacy card-free trial (pre-card-upfront publications). A
  # subscription supersedes it; a lapsed subscription can still coast on
  # whatever trial time remains.
  def in_trial?
    trial_ends_at&.future? && !subscribed?
  end

  # The one question the game-rotation gate asks.
  def billing_active?
    complimentary? || subscribed? || in_trial?
  end

  # An in-app cancellation is pending: paid through the period end, then
  # Stripe deletes the subscription and the deleted webhook downgrades us.
  def cancel_scheduled?
    subscription_cancel_at_period_end?
  end

  # The Billing card and publication badges key off this one symbol.
  # :pending = created under card-upfront billing but never confirmed.
  def billing_state
    if complimentary?
      :complimentary
    elsif subscription_status == "past_due"
      :past_due
    elsif subscribed?
      :subscribed
    elsif in_trial?
      :trialing
    elsif stripe_subscription_id.present?
      :canceled
    elsif trial_ends_at.present?
      :trial_expired
    else
      :pending
    end
  end

  # Trial to attach when this publication's subscription is created. A brand
  # new publication gets the full trial; a legacy publication confirming
  # mid-trial keeps its remaining runway; a restart (or an expired trial)
  # pays from day one.
  def stripe_trial_params
    if stripe_subscription_id.blank? && trial_ends_at.nil?
      { trial_period_days: TRIAL_LENGTH.in_days.to_i }
    elsif stripe_subscription_id.blank? && trial_ends_at.future?
      { trial_end: trial_ends_at.to_i }
    else
      {}
    end
  end

  # Copy status + renewal date from a Stripe::Subscription. Called from the
  # confirm action, the checkout return page, and the customer.subscription.*
  # webhooks, whichever lands first -- belt and suspenders. The customer id
  # is written up to the account, which owns the Customer for all of its
  # publications.
  def sync_stripe_subscription!(subscription)
    transaction do
      update!(
        stripe_subscription_id: subscription.id,
        subscription_status: subscription.status,
        subscription_current_period_end: period_end_from(subscription),
        subscription_cancel_at_period_end: subscription.try(:cancel_at_period_end) || false
      )
      customer_id = customer_id_from(subscription)
      if customer_id.present? && account.stripe_customer_id.blank?
        account.update!(stripe_customer_id: customer_id)
      end
    end
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
