class Billings::PortalsController < ApplicationController
  include AccountScoping
  before_action :require_account_owner

  # One-time URL into the Stripe-hosted billing portal (update card, view
  # invoices). The portal is customer-level: one card, every subscription.
  def create
    if Current.account.stripe_customer_id.blank?
      redirect_to account_billing_path,
        alert: "No billing info yet: it's collected when you confirm your first subscription." and return
    end

    portal = Payments.platform.create_billing_portal_session(
      customer: Current.account.stripe_customer_id,
      return_url: account_billing_url
    )
    redirect_to portal.url, allow_other_host: true
  end
end
