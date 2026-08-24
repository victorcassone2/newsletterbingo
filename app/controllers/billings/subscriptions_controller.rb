class Billings::SubscriptionsController < ApplicationController
  include AccountScoping, SubscriptionStarting

  # One button on the Billing page: subscribe (or restart). No confirm
  # interstitial -- the button itself carries the price, and hosted Checkout
  # is its own confirmation when a card still needs collecting.
  def create
    if Current.account.subscribed?
      redirect_to account_billing_path, notice: "You're already subscribed."
    else
      start_subscription_or_checkout(landing_path: account_billing_path)
    end
  end
end
