class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    account_name = params[:account_name].presence || "My Publisher"

    if @user.valid?
      ActiveRecord::Base.transaction do
        @user.save!
        account = Account.create!(name: account_name)
        Membership.create!(account: account, user: @user, role: "owner")
      end
      start_new_session_for @user
      redirect_to dashboard_path, notice: "Welcome! Create your first publication to get started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
