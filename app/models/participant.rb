class Participant < ApplicationRecord
  belongs_to :publication
  has_many :daily_claims, dependent: :destroy
  has_many :bingo_boards, dependent: :destroy
  has_many :prize_awards, dependent: :destroy

  has_secure_token :public_token, length: 36

  normalizes :email, with: ->(e) { e.strip.downcase }

  # Uniqueness (publication + email) is enforced by the database index so
  # create_or_find_by! can arbitrate races.
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # One participant per publication + normalized email, created on first
  # claim. Concurrency-safe via the unique index.
  def self.locate_or_register(publication, email)
    publication.participants.create_or_find_by!(email: normalize_value_for(:email, email))
  end

  def board_for(game)
    bingo_boards.find_by(game: game) || BingoBoard.generate_for(self, game)
  end

  def claim_count_for(game)
    daily_claims.where(game: game).count
  end
end
