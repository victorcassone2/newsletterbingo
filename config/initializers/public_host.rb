# The externally reachable origin used in newsletter claim links.
module NewsletterBingo
  # APP_HOST is accepted with or without a scheme: claim links embedded in
  # newsletters need a full origin, while Action Mailer wants a bare host.
  def self.public_host
    origin = ENV.fetch("APP_HOST") { Rails.env.production? ? "https://app.dailybingo.example" : "http://localhost:3000" }
    if origin.match?(%r{\Ahttps?://})
      origin
    else
      "https://#{origin}"
    end
  end
end
