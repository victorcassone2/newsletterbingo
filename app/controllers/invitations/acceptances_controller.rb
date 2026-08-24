class Invitations::AcceptancesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_invitation

  def show
    if !authenticated? && invited_user_exists?
      session[:return_to_after_authenticating] = request.url
    end
    @user = User.new(email_address: @invitation.email_address)
  end

  def create
    if authenticated?
      @invitation.accept_for(Current.user)
      redirect_to account_path(account_id: @invitation.account_id),
        notice: "You've joined #{@invitation.account.name}."
    elsif invited_user_exists?
      session[:return_to_after_authenticating] = invitation_acceptance_url(@invitation.token)
      redirect_to new_session_path, alert: "Sign in to accept your invitation."
    else
      @user = User.new(user_params.merge(email_address: @invitation.email_address))

      if @user.save
        @invitation.accept_for(@user)
        start_new_session_for @user
        redirect_to account_path(account_id: @invitation.account_id),
          notice: "Welcome to #{@invitation.account.name}!"
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  private
    def set_invitation
      @invitation = Invitation.find_by!(token: params[:invitation_token])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: "That invitation is no longer valid."
    end

    def invited_user_exists?
      User.exists?(email_address: @invitation.email_address)
    end

    def user_params
      params.require(:user).permit(:password, :password_confirmation)
    end
end
