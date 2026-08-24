# Stripe configuration (publication subscriptions).
#
# Keys come from ENV; never hardcode them. This app bills through its own
# Stripe account ("Newsletter Bingo") -- separate from local_deal_engine's
# ClaimStreet account so checkout and statements carry the right business
# name. The price env var keeps a BINGO_ prefix so the two apps can never
# collide on shared infrastructure.
#
# The webhook signing secret is read by the webhook controller via
# Payments.construct_webhook_event. No publishable key: the whole flow is
# Stripe-hosted Checkout + Billing Portal (redirects), not Stripe.js/Elements.
Rails.application.config.stripe = {
  secret_key: ENV["STRIPE_SECRET_KEY"],
  webhook_secret: ENV["STRIPE_WEBHOOK_SECRET"],
  # The $29/month publication subscription Price (price_...).
  price_id: ENV["STRIPE_BINGO_PRICE_ID"]
}

# The suite never talks to Stripe for real (calls are stubbed), but the code
# paths read these values, so fill any blank with a recognizable dummy in test.
if Rails.env.test?
  Rails.application.config.stripe.transform_values! { |value| value.presence || "sk_test_dummy" }
end

Stripe.api_key = Rails.application.config.stripe[:secret_key]
