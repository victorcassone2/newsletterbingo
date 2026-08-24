class Publications::SubscriptionsController < Publications::BaseController
  before_action :redirect_if_subscribed

  # The confirm screen, shown right after a newsletter is created (and again
  # for restarts). Billing info lives on the account; this page only confirms
  # this publication's $29/month subscription against it.
  def new
    @payment_method = Current.account.stripe_payment_method
  end

  # Card on file: create the subscription directly -- confirming is the whole
  # flow. No card yet: bounce to Stripe-hosted Checkout, which collects one
  # and attaches it to the account's customer for every later confirm.
  def create
    Current.account.ensure_stripe_customer!
    payment_method = Current.account.stripe_payment_method
    if payment_method
      confirm_subscription(payment_method)
    else
      redirect_to_subscription_checkout
    end
  end

  private
    def redirect_if_subscribed
      if @publication.subscribed?
        redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"),
          notice: "This publication is already subscribed."
      end
    end

    def confirm_subscription(payment_method)
      restart = @publication.stripe_subscription_id.present?
      subscription = Payments.platform.create_subscription(
        customer: Current.account.stripe_customer_id,
        items: [ { price: subscription_price_id } ],
        default_payment_method: payment_method.id,
        metadata: { publication_id: @publication.id, account_id: Current.account.id },
        **@publication.stripe_trial_params
      )
      @publication.sync_stripe_subscription!(subscription)
      if restart
        redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing"),
          notice: "You're resubscribed. Games will keep rotating."
      else
        redirect_to edit_account_publication_path(id: @publication.id), notice: confirmation_notice
      end
    end

    def confirmation_notice
      if @publication.subscription_status == "trialing"
        "You're set — free until #{@publication.subscription_current_period_end&.strftime("%B %-d")}, then $29/month. Now connect your newsletter."
      else
        "You're subscribed. Now connect your newsletter."
      end
    end

    def redirect_to_subscription_checkout
      session = Payments.platform.create_checkout_session(
        mode: "subscription",
        customer: Current.account.stripe_customer_id,
        line_items: [ { price: subscription_price_id, quantity: 1 } ],
        # publication_id rides on the subscription itself so the webhook can
        # resolve the publication even if the subscription-id lookup misses.
        subscription_data: {
          metadata: { publication_id: @publication.id, account_id: Current.account.id },
          **@publication.stripe_trial_params
        },
        # {CHECKOUT_SESSION_ID} is substituted by Stripe; keep the braces
        # literal (the URL helper would percent-encode them).
        success_url: "#{account_publication_subscription_return_url(publication_id: @publication.id)}?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: new_account_publication_subscription_url(publication_id: @publication.id)
      )
      redirect_to session.url, allow_other_host: true
    end

    def subscription_price_id
      Rails.application.config.stripe[:price_id].presence or
        raise Payments::MisconfiguredError, "no Stripe price is configured"
    end
end
