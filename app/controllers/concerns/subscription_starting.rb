# Starts the account's one subscription from wherever the commitment happens
# (creating a publication, the Billing page). Card on file: the subscription
# is created directly and the user never leaves the app. No card: bounce to
# Stripe-hosted Checkout, which collects one and attaches it to the account's
# customer for good.
module SubscriptionStarting
  private
    def start_subscription_or_checkout(landing_path:, publication: nil)
      Current.account.ensure_stripe_customer!
      payment_method = Current.account.stripe_payment_method
      if payment_method
        Current.account.start_subscription!(payment_method)
        redirect_to landing_path, notice: subscription_started_notice
      else
        redirect_to checkout_session_for(publication).url, allow_other_host: true
      end
    end

    def subscription_started_notice
      if Current.account.trialing?
        "You're set: free until #{Current.account.subscription_current_period_end&.strftime("%B %-d")}, " \
          "then $#{Current.account.monthly_price}/month."
      else
        "You're subscribed: $#{Current.account.monthly_price}/month. Games will keep rotating."
      end
    end

    def checkout_session_for(publication)
      Payments.platform.create_checkout_session(
        mode: "subscription",
        customer: Current.account.stripe_customer_id,
        line_items: [ { price: Payments.price_id, quantity: Current.account.subscription_quantity } ],
        # account_id rides on the subscription itself so the webhook can
        # resolve the account even if the subscription-id lookup misses.
        subscription_data: {
          metadata: { account_id: Current.account.id },
          **Current.account.stripe_trial_params
        },
        # {CHECKOUT_SESSION_ID} is substituted by Stripe; keep the braces
        # literal (the URL helper would percent-encode them).
        success_url: checkout_success_url(publication),
        cancel_url: checkout_cancel_url(publication)
      )
    end

    def checkout_success_url(publication)
      url = "#{account_billing_subscription_return_url}?session_id={CHECKOUT_SESSION_ID}"
      publication ? "#{url}&publication_id=#{publication.id}" : url
    end

    def checkout_cancel_url(publication)
      publication ? edit_account_publication_url(id: publication.id) : account_billing_url
    end
end
