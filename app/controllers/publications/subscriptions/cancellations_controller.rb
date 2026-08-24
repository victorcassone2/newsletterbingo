class Publications::Subscriptions::CancellationsController < Publications::BaseController
  # Cancel at period end: the month is already paid for, the running game
  # plays out, and Stripe deletes the subscription when the clock runs out
  # (the deleted webhook downgrades us then).
  def create
    if @publication.stripe_subscription_id.present?
      subscription = Payments.platform.update_subscription(
        @publication.stripe_subscription_id, cancel_at_period_end: true
      )
      @publication.sync_stripe_subscription!(subscription)
    end
    redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"),
      notice: "Your subscription ends #{period_end_phrase}. Games run until then."
  end

  # Change of heart before the period runs out: keep the subscription going.
  def destroy
    if @publication.stripe_subscription_id.present? && @publication.cancel_scheduled?
      subscription = Payments.platform.update_subscription(
        @publication.stripe_subscription_id, cancel_at_period_end: false
      )
      @publication.sync_stripe_subscription!(subscription)
    end
    redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"),
      notice: "Cancellation undone — your subscription continues."
  end

  private
    def period_end_phrase
      date = @publication.subscription_current_period_end
      date ? "on #{date.strftime("%B %-d, %Y")}" : "at the end of the paid period"
    end
end
