class Publications::Subscriptions::ReturnsController < Publications::BaseController
  # Stripe sends the user back here after Checkout. Sync the subscription now
  # instead of waiting on the webhook, so the Billing card reflects the new
  # state immediately -- belt and suspenders with the webhook.
  def show
    session_id = params[:session_id]
    if session_id.blank?
      redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing") and return
    end

    checkout = Payments.platform.retrieve_checkout_session(session_id)
    if own_checkout?(checkout) && checkout.subscription.present?
      subscription = Payments.platform.retrieve_subscription(checkout.subscription)
      @publication.sync_stripe_subscription!(subscription)
    end

    notice = @publication.subscribed? ?
      "You're subscribed. Your games will keep rotating." :
      "Checkout didn't finish. You can subscribe whenever you're ready."
    redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"), notice: notice
  end

  private
    # Only sync from a session that belongs to this account's customer --
    # a pasted-in foreign session_id must not overwrite subscription state.
    def own_checkout?(checkout)
      checkout.customer.present? && checkout.customer == Current.account.stripe_customer_id
    end
end
