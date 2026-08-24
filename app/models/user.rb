class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }

  def member_of?(account)
    memberships.exists?(account_id: account.id)
  end

  def owner_of?(account)
    memberships.owner.exists?(account_id: account.id)
  end

  def can_access?(account)
    owner_of?(account) || !account.deactivated?
  end
end
