class Billings::Subscriptions::ReturnsController < ApplicationController
  include AccountScoping

  # Stripe sends the user back here after Checkout. Sync the subscription now
  # instead of waiting on the webhook, so the page reflects the new state
  # immediately -- belt and suspenders with the webhook. When checkout began
  # from creating a publication, land back on that publication's Setup.
  def show
    session_id = params[:session_id]
    if session_id.blank?
      redirect_to account_billing_path and return
    end

    checkout = Payments.platform.retrieve_checkout_session(session_id)
    if own_checkout?(checkout) && checkout.subscription.present?
      subscription = Payments.platform.retrieve_subscription(checkout.subscription)
      Current.account.sync_stripe_subscription!(subscription)
    end

    if Current.account.subscribed?
      redirect_to landing_path, notice: "You're set — now connect your newsletter."
    else
      redirect_to account_billing_path,
        notice: "Checkout didn't finish. You can subscribe whenever you're ready."
    end
  end

  private
    # Only sync from a session that belongs to this account's customer --
    # a pasted-in foreign session_id must not overwrite subscription state.
    def own_checkout?(checkout)
      checkout.customer.present? && checkout.customer == Current.account.stripe_customer_id
    end

    def landing_path
      publication = Current.account.publications.find_by(id: params[:publication_id])
      publication ? edit_account_publication_path(id: publication.id) : account_billing_path
    end
end
