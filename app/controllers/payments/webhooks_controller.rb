class Payments::WebhooksController < ActionController::Base
  # Stripe posts here server-to-server: no CSRF token, no session. Authenticity
  # comes from the signature check below, not the Rails forgery token.
  skip_forgery_protection

  def create
    event = Payments.construct_webhook_event(
      request.body.read,
      request.env["HTTP_STRIPE_SIGNATURE"]
    )
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  else
    handle(event)
    head :ok
  end

  private
    def handle(event)
      case event.type
      when "customer.subscription.created",
           "customer.subscription.updated",
           "customer.subscription.deleted" then sync_subscription(event)
      end
    end

    # Account subscription lifecycle: created/renewed/payment failed/
    # canceled all funnel through here. This is what closes (and reopens)
    # the game-rotation gate when billing state changes.
    def sync_subscription(event)
      subscription = event.data.object
      ProcessedWebhookEvent.once(event.id) do
        account = account_for(subscription)
        next false unless account
        account.sync_stripe_subscription!(subscription)
        true
      end
    end

    # Our stored subscription id first; fall back to the metadata stamped on
    # the subscription at checkout, which covers the first event arriving
    # before the return page has stored the id. The fallback only applies to
    # an account with no subscription yet, so a stray event from some other
    # subscription (e.g. a pre-migration per-publication one) can never
    # overwrite the live one's state.
    def account_for(subscription)
      Account.find_by(stripe_subscription_id: subscription.id) ||
        Account.where(stripe_subscription_id: nil)
          .find_by(id: subscription.metadata&.[]("account_id"))
    end
end
