# Each publication carries its own $29/month Stripe subscription, billed to
# the account's one Stripe Customer. New publications get a 30-day app-side
# trial (one full game arc) with no card and no Stripe objects. Status lives
# in local columns synced from webhooks and the checkout return page --
# request paths never call Stripe to answer "is this publication paid?".
#
# Lapsing is gentle by design: gating acts at game-rotation time only, so a
# running game always plays out to its natural end. Readers are never
# punished mid-game; the next game simply doesn't start.
module Publication::Billable
  extend ActiveSupport::Concern

  # One full game arc (24 days) plus a week of runway, no card required.
  TRIAL_LENGTH = 30.days

  included do
    before_create { self.trial_ends_at ||= TRIAL_LENGTH.from_now }
  end

  # Stripe statuses that count as subscribed. past_due rides Stripe's retry
  # cycle as a grace period; canceled/unpaid lapse back to unpaid.
  SUBSCRIBED_STATUSES = %w[ active trialing past_due ].freeze

  def subscribed?
    subscription_status.in?(SUBSCRIBED_STATUSES)
  end

  # The card-free launch trial. A subscription supersedes it; a lapsed
  # subscription can still coast on whatever trial time remains.
  def in_trial?
    trial_ends_at&.future? && !subscribed?
  end

  # The one question the game-rotation gate asks.
  def billing_active?
    complimentary? || subscribed? || in_trial?
  end

  # The Billing card and publication badges key off this one symbol.
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
    else
      :trial_expired
    end
  end

  # Copy status + renewal date from a Stripe::Subscription. Called from the
  # checkout return page and the customer.subscription.* webhooks, whichever
  # lands first -- belt and suspenders. The customer id is written up to the
  # account, which owns the Customer for all of its publications.
  def sync_stripe_subscription!(subscription)
    transaction do
      update!(
        stripe_subscription_id: subscription.id,
        subscription_status: subscription.status,
        subscription_current_period_end: period_end_from(subscription)
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
