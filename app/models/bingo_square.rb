class BingoSquare < ApplicationRecord
  belongs_to :bingo_board
  belongs_to :game_word, optional: true

  validates :position, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }
  validate :only_center_free

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

  private
    # The board's center position depends on its game's board size, so
    # the FREE-square rule lives here rather than in a check constraint.
    def only_center_free
      if game_word_id.nil? && bingo_board && position != bingo_board.center
        errors.add(:game_word, "is required off the FREE center")
      end
    end
end
