class Publications::SubscriptionsController < Publications::BaseController
  # One button covers subscribe and resubscribe: find or create the account's
  # Billing customer, then bounce to Stripe-hosted Checkout in subscription
  # mode. The customer lives on the account (one card for all its
  # publications); the subscription belongs to this publication.
  def create
    if @publication.subscribed?
      redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"),
        notice: "This publication is already subscribed." and return
    end

    Current.account.ensure_stripe_customer!
    redirect_to_subscription_checkout
  end

  private
    def redirect_to_subscription_checkout
      session = Payments.platform.create_checkout_session(
        mode: "subscription",
        customer: Current.account.stripe_customer_id,
        line_items: [ { price: subscription_price_id, quantity: 1 } ],
        # publication_id rides on the subscription itself so the webhook can
        # resolve the publication even if the subscription-id lookup misses.
        subscription_data: { metadata: { publication_id: @publication.id, account_id: Current.account.id } },
        # {CHECKOUT_SESSION_ID} is substituted by Stripe; keep the braces
        # literal (the URL helper would percent-encode them).
        success_url: "#{account_publication_subscription_return_url(publication_id: @publication.id)}?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: edit_account_publication_url(id: @publication.id, anchor: "billing")
      )
      redirect_to session.url, allow_other_host: true
    end

    def subscription_price_id
      Rails.application.config.stripe[:price_id].presence or
        raise Payments::MisconfiguredError, "no Stripe price is configured"
    end
end
