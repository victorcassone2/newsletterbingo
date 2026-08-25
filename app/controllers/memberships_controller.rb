class MembershipsController < ApplicationController
  include AccountScoping
  before_action :require_account_owner
  before_action :set_membership

  def update
    if @membership.update(role: params.require(:membership)[:role])
      redirect_to people_path, notice: "#{@membership.user.email_address} is now #{@membership.role == "owner" ? "an owner" : "a member"}."
    else
      redirect_to people_path, alert: @membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @membership.destroy
      if @membership.user == Current.user
        redirect_to dashboard_path, notice: "You left #{@membership.account.name}."
      else
        redirect_to people_path, notice: "#{@membership.user.email_address} was removed."
      end
    else
      redirect_to people_path, alert: @membership.errors.full_messages.to_sentence
    end
  end

  private
    def set_membership
      @membership = Current.account.memberships.find(params[:id])
    end

    def people_path
      account_account_profile_path(account_id: Current.account.id)
    end
end
