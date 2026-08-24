class Membership < ApplicationRecord
  ROLES = %w[ owner member ]

  belongs_to :account
  belongs_to :user

  scope :owner, -> { where(role: "owner") }

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :account_keeps_an_owner, on: :update

  before_destroy :ensure_account_keeps_an_owner

  def owner?
    role == "owner"
  end

  def last_owner?
    owner? && no_other_owner?
  end

  private
    def account_keeps_an_owner
      if role_changed?(from: "owner") && no_other_owner?
        errors.add(:base, "The account needs at least one owner")
      end
    end

    def ensure_account_keeps_an_owner
      if last_owner?
        errors.add(:base, "The account needs at least one owner")
        throw :abort
      end
    end

    def no_other_owner?
      account.memberships.owner.where.not(id: id).none?
    end
end
