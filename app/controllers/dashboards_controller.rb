# The signed-in front door: sends a user into the first account they can
# access. Flash set by whoever redirected here is kept through the
# pass-through so it still renders on the destination page.
class DashboardsController < ApplicationController
  def show
    account = Current.user.accounts.order(:created_at).detect { |a| Current.user.can_access?(a) }
    if account
      flash.keep
      redirect_to account_publications_path(account_id: account.id)
    elsif Current.user.accounts.any?
      render :deactivated
    else
      flash.keep
      redirect_to new_registration_path
    end
  end
end
