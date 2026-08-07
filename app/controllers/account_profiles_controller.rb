class AccountProfilesController < ApplicationController
  include AccountScoping

  def show
    @memberships = Current.account.memberships.includes(:user).order(:created_at)
  end
end
