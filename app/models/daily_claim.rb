class DailyClaim < ApplicationRecord
  belongs_to :participant
  belongs_to :daily_call
  belongs_to :game

  # Uniqueness (participant + daily_call) is enforced by the database index
  # so create_or_find_by! can arbitrate races.
  validates :claimed_at, presence: true
end
