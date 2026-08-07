class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :publications, dependent: :destroy

  validates :name, presence: true

  def owners
    users.merge(Membership.owner)
  end
end
