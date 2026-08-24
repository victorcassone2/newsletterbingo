# Preview all emails at http://localhost:3000/rails/mailers/invitations_mailer
class InvitationsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/invitations_mailer/invite
  def invite
    InvitationsMailer.invite(Invitation.first || Invitation.new(account: Account.first, email_address: "teammate@example.com", token: "preview"))
  end
end
