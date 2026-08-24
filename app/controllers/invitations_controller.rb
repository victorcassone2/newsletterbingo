class InvitationsController < ApplicationController
  include AccountScoping

  def create
    invitation = Current.account.invitations.new(invitation_params)

    if invitation.save
      invitation.deliver_later
      redirect_to people_path, notice: "Invitation sent to #{invitation.email_address}."
    else
      redirect_to people_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.account.invitations.find(params[:id]).destroy
    redirect_to people_path, notice: "Invitation cancelled."
  end

  private
    def invitation_params
      params.require(:invitation).permit(:email_address)
    end

    def people_path
      account_account_profile_path(account_id: Current.account.id)
    end
end
