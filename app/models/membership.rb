class Membership < ApplicationRecord
  ROLES = %w[ owner member ]

  belongs_to :account
  belongs_to :user

  scope :owner, -> { where(role: "owner") }

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }

  def owner?
    role == "owner"
  end
end
