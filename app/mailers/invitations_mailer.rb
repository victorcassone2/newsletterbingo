class InvitationsMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    mail subject: "You're invited to join #{invitation.account.name} on Daily Bingo",
      to: invitation.email_address
  end
end
