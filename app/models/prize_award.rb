class PrizeAward < ApplicationRecord
  belongs_to :participant
  belongs_to :game
  belongs_to :prize

  validates :kind, inclusion: { in: Prize::KINDS }
  validates :awarded_at, presence: true
  validates :prize_name, presence: true

  scope :line, -> { where(kind: "line") }
  scope :blackout, -> { where(kind: "blackout") }
end
