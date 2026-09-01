require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on S3 (see config/storage.yml). Heroku's filesystem is
  # ephemeral, so local disk would drop uploads on every deploy and dyno restart.
  config.active_storage.service = :amazon

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # The Solid Queue supervisor runs inside Puma (SOLID_QUEUE_IN_PUMA), which is
  # what drives the hourly RotateGamesJob in config/recurring.yml.
  config.active_job.queue_adapter = :solid_queue

  # Raise rather than swallow delivery failures: a lost invitation or password
  # reset is worse than a visible error.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  # APP_HOST doubles as the claim-link origin (see
  # config/initializers/public_host.rb), so it may carry a scheme; both the
  # mailer and host authorization below want the bare host. Computed here
  # rather than read from NewsletterBingo.public_host because environment
  # files load before initializers.
  canonical_host = ENV.fetch("APP_HOST", "newsletterbingo.herokuapp.com").sub(%r{\Ahttps?://}, "")

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: canonical_host, protocol: "https" }

  # Email via Mailgun SMTP. MAILGUN_DOMAIN is the verified sending domain;
  # credentials come from Heroku config vars.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("MAILGUN_SMTP_ADDRESS", "smtp.mailgun.org"),
    port: 587,
    domain: ENV["MAILGUN_DOMAIN"],
    user_name: ENV["MAILGUN_SMTP_USERNAME"],
    password: ENV["MAILGUN_SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks. www is on
  # the list because the router's redirect to the apex has to see the request
  # before it can redirect it, and the herokuapp.com domain stays allowed so
  # platform routing and one-off dyno access keep working.
  config.hosts = [
    canonical_host,
    "www.#{canonical_host}",
    ENV["HEROKU_APP_DEFAULT_DOMAIN_NAME"]
  ].compact_blank

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
