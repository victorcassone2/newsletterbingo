class Publications::Subscriptions::PortalsController < Publications::BaseController
  # One-time URL into the Stripe-hosted billing portal (update card, view
  # invoices, cancel). The portal is customer-level, so it shows every
  # subscription the account holds in one place.
  def create
    if Current.account.stripe_customer_id.blank?
      redirect_to edit_account_publication_path(id: @publication.id, anchor: "billing") and return
    end

    portal = Payments.platform.create_billing_portal_session(
      customer: Current.account.stripe_customer_id,
      return_url: edit_account_publication_url(id: @publication.id, anchor: "billing")
    )
    redirect_to portal.url, allow_other_host: true
  end
end
