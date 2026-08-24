class AccountDeactivation < ApplicationRecord
  belongs_to :account

  validates :account_id, uniqueness: true
end
