class AccountProfilesController < ApplicationController
  include AccountScoping

  def show
    @memberships = Current.account.memberships.includes(:user).order(:created_at)
    @owner = Current.user.owner_of?(Current.account)
    @invitations = Current.account.invitations.order(:created_at)
    @invitation = Current.account.invitations.new
  end
end
