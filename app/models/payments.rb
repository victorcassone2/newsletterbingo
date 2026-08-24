# The single seam between the app and Stripe. Every Stripe call goes through
# Payments.platform, so tests stub one object and no call site ever touches
# Stripe:: classes directly.
module Payments
  MisconfiguredError = Class.new(StandardError)

  def self.platform
    config[:secret_key].presence or raise MisconfiguredError, "no Stripe secret key is configured"
    Gateway.new(config[:secret_key])
  end

  # Verify a webhook signature. Only one endpoint (and so one secret) exists
  # today, but keep the try-each shape from local_deal_engine so a second
  # secret (e.g. during a secret rotation) is a config change, not a code one.
  def self.construct_webhook_event(payload, signature)
    error = nil
    webhook_secrets.each do |secret|
      return Stripe::Webhook.construct_event(payload, signature, secret)
    rescue Stripe::SignatureVerificationError => e
      error = e
    end
    raise error
  end

  def self.webhook_secrets
    secrets = [ config[:webhook_secret] ].compact.uniq
    secrets.empty? ? [ nil ] : secrets
  end

  def self.config
    Rails.application.config.stripe
  end

  class Gateway
    def initialize(api_key)
      @api_key = api_key
    end

    def create_customer(**params)
      Stripe::Customer.create(params, { api_key: @api_key })
    end

    def create_checkout_session(**params)
      Stripe::Checkout::Session.create(params, { api_key: @api_key })
    end

    def retrieve_checkout_session(id)
      Stripe::Checkout::Session.retrieve(id, { api_key: @api_key })
    end

    def retrieve_subscription(id)
      Stripe::Subscription.retrieve(id, { api_key: @api_key })
    end

    # Stripe-hosted billing portal (update card, cancel). Sessions are
    # single-use short-lived URLs -- mint fresh, never store.
    def create_billing_portal_session(**params)
      Stripe::BillingPortal::Session.create(params, { api_key: @api_key })
    end
  end
end
