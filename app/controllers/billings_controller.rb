class BillingsController < ApplicationController
  include AccountScoping

  # The account's one billing home: payment method and invoices live in the
  # Stripe portal; each publication's subscription state is summarized here
  # from local columns (no Stripe calls on render).
  def show
  end
end
