class BillingsController < ApplicationController
  include AccountScoping
  before_action :require_account_owner

  # The account's one billing home: payment method and invoices live in the
  # Stripe portal; each publication's subscription state is summarized here
  # from local columns (no Stripe calls on render).
  def show
    @page = Page.new(Current.account.publications.includes(:closure).order(:name), number: params[:page])
  end
end
