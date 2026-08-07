class HomeController < ApplicationController
  def show
    account = Current.user.accounts.order(:created_at).first
    if account
      redirect_to account_publications_path(account_id: account.id)
    else
      redirect_to new_registration_path
    end
  end
end
