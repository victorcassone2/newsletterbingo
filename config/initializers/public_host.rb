# The externally reachable origin used in newsletter claim links.
module DailyBingo
  def self.public_host
    ENV.fetch("APP_HOST") { Rails.env.production? ? "https://app.dailybingo.example" : "http://localhost:3000" }
  end
end
