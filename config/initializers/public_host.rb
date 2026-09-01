# The externally reachable origin used in newsletter claim links.
module NewsletterBingo
  # Development's origin. Production has no default on purpose: see
  # config/initializers/required_env.rb for why a wrong host there is worse
  # than no boot at all.
  DEFAULT_HOST = "http://localhost:3000"

  # APP_HOST is accepted with or without a scheme: claim links embedded in
  # newsletters need a full origin, while Action Mailer wants a bare host.
  def self.public_host
    origin = ENV["APP_HOST"].presence || DEFAULT_HOST
    if origin.match?(%r{\Ahttps?://})
      origin
    else
      "https://#{origin}"
    end
  end
end
