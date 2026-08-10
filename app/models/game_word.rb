class GameWord < ApplicationRecord
  belongs_to :game
  belongs_to :word
  # Foreign keys guard against deleting a word out from under calls or
  # squares; Game's cascade destroys those first.
  has_one :daily_call
  has_many :bingo_squares

  validates :label, presence: true
  validates :position, presence: true
end
