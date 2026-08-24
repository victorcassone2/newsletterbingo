class DeactivationsController < ApplicationController
  include AccountScoping
  before_action :require_account_owner

  def create
    Current.account.create_deactivation! unless Current.account.deactivated?
    redirect_to people_path, notice: "#{Current.account.name} is deactivated. Only owners can access it now."
  end

  def destroy
    Current.account.deactivation&.destroy
    redirect_to people_path, notice: "#{Current.account.name} is active again."
  end

  private
    def people_path
      account_account_profile_path(account_id: Current.account.id)
    end
end
