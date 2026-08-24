class Billings::Subscriptions::CancellationsController < ApplicationController
  include AccountScoping

  # Cancel at period end: the month is already paid for, running games play
  # out, and Stripe deletes the subscription when the clock runs out (the
  # deleted webhook downgrades us then).
  def create
    if Current.account.stripe_subscription_id.present?
      subscription = Payments.platform.update_subscription(
        Current.account.stripe_subscription_id, cancel_at_period_end: true
      )
      Current.account.sync_stripe_subscription!(subscription)
    end
    redirect_to account_billing_path,
      notice: "Your subscription ends #{period_end_phrase}. Games run until then."
  end

  # Change of heart before the period runs out: keep the subscription going.
  def destroy
    if Current.account.stripe_subscription_id.present? && Current.account.cancel_scheduled?
      subscription = Payments.platform.update_subscription(
        Current.account.stripe_subscription_id, cancel_at_period_end: false
      )
      Current.account.sync_stripe_subscription!(subscription)
    end
    redirect_to account_billing_path, notice: "Cancellation undone — your subscription continues."
  end

  private
    def period_end_phrase
      date = Current.account.subscription_current_period_end
      date ? "on #{date.strftime("%B %-d, %Y")}" : "at the end of the paid period"
    end
end
