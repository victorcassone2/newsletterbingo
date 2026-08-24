class Invitation < ApplicationRecord
  has_secure_token

  belongs_to :account

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :account_id, message: "has already been invited" }
  validate :email_address_not_already_a_member

  def deliver_later
    InvitationsMailer.invite(self).deliver_later
  end

  def accept_for(user)
    transaction do
      account.memberships.where(user: user).first_or_create!
      destroy!
    end
  end

  private
    def email_address_not_already_a_member
      if account && account.users.exists?(email_address: email_address)
        errors.add(:email_address, "already belongs to this team")
      end
    end
end
