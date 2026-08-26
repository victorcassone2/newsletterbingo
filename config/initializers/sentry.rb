# Error reporting.
#
# Sentry only starts when SENTRY_DSN is present, so development and test runs
# stay silent and no DSN is committed to the repository. The DSN is set as a
# Heroku config var.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # Participants' email addresses move through this app, so request bodies,
    # headers and IP addresses stay out of Sentry. Turning this on would send
    # reader data to a third party, which is a decision to make deliberately
    # rather than inherit from a generated snippet.
    config.send_default_pii = false

    # Traces cost quota. Start low and raise it only if they are being read.
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  end
end
