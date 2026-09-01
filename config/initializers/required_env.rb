# Config vars production cannot guess, checked at boot.
#
# Both of these fail *silently* when they are missing: the app boots, serves,
# and does the wrong thing quietly for as long as nobody notices. A wrong
# APP_HOST mints claim links pointing at a domain that isn't ours, so every
# reader who taps the bingo button in a send lands nowhere and the publisher
# hears about it from their readers. A wrong MAIL_FROM is a domain Mailgun
# won't send for, and raise_delivery_errors turns that into a 500 on the
# invitation and password-reset paths. Refusing to boot is the cheaper
# failure in both cases, and the deploy that introduced it is still on screen.
#
# Everything else production needs announces itself: Stripe raises
# Payments::MisconfiguredError, Active Storage and Action Mailer SMTP fail
# their own calls, and Sentry is deliberately optional. Those stay off this
# list rather than turning an unrelated blank into a dead app. The full set
# of config vars is in the README's Deployment section.
REQUIRED_PRODUCTION_ENV = {
  "APP_HOST" => "the origin every newsletter claim link is built from, e.g. newsletterbingo.com",
  "MAIL_FROM" => "the From address on invitations and password resets, on a Mailgun-verified domain"
}

# Asset builds load the app without config vars, and nothing that needs a host
# or a From address runs during precompile. The Dockerfile and the Heroku
# buildpack both mark that pass with SECRET_KEY_BASE_DUMMY.
building_assets = ENV["SECRET_KEY_BASE_DUMMY"].present?

if Rails.env.production? && !building_assets
  missing = REQUIRED_PRODUCTION_ENV.reject { |name, _| ENV[name].present? }

  if missing.any?
    raise "Missing required production config vars:\n" +
      missing.map { |name, purpose| "  #{name}: #{purpose}" }.join("\n") +
      "\n\nSet them with `heroku config:set NAME=value` before deploying."
  end
end
