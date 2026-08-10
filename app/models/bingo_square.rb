class BingoSquare < ApplicationRecord
  belongs_to :bingo_board
  belongs_to :game_word, optional: true

  validates :position, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }

  def free?
    game_word_id.nil?
  end

  # The FREE center always counts as claimed.
  def claimed?
    free? || claimed_at.present?
  end

  def label
    free? ? "FREE" : game_word.label
  end

  # The call that claimed (or will claim) this square, source of its
  # description, link, and prize treatment.
  def daily_call
    game_word&.daily_call
  end
end
