class Account < ApplicationRecord
  include Billable

  has_many :memberships, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :users, through: :memberships
  has_many :publications, dependent: :destroy
  has_one :deactivation, class_name: "AccountDeactivation", dependent: :destroy

  validates :name, presence: true

  def owners
    users.merge(Membership.owner)
  end

  def deactivated?
    deactivation.present?
  end
end
