class HomeController < ApplicationController
  def show
    account = Current.user.accounts.order(:created_at).detect { |a| Current.user.can_access?(a) }
    if account
      redirect_to account_publications_path(account_id: account.id)
    elsif Current.user.accounts.any?
      render :deactivated
    else
      redirect_to new_registration_path
    end
  end
end
