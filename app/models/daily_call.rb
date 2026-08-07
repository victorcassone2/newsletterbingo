class DailyCall < ApplicationRecord
  class NotClaimable < StandardError; end
  class WordLocked < StandardError; end

  belongs_to :game
  belongs_to :game_word
  belongs_to :sponsor, optional: true
  has_many :daily_claims, dependent: :destroy
  has_one :publication, through: :game

  scope :chronological, -> { order(:call_on) }

  validates :call_on, presence: true, uniqueness: { scope: :game_id }
  validates :link_url, http_url: true
  validates :link_text, presence: true, if: -> { link_url.present? }

  delegate :label, to: :game_word

  def claimable_now?
    game.active? && call_on == publication.local_date
  end

  # A call is "called" once its local date has arrived.
  def called?(date = publication.local_date)
    call_on <= date
  end

  def today?(date = publication.local_date)
    call_on == date
  end

  def upcoming?(date = publication.local_date)
    call_on > date
  end

  def day_number
    game.day_number(call_on)
  end

  # Historical calls, and calls someone has already claimed, keep their word.
  def word_changeable?
    call_on >= publication.local_date && daily_claims.none?
  end

  # Swap words with another uncalled call (reordering the future schedule).
  # The unique (game, game_word) constraint is deferred, so this is atomic.
  def swap_word_with(other_call)
    raise WordLocked unless word_changeable? && other_call.word_changeable?

    transaction do
      ours, theirs = game_word_id, other_call.game_word_id
      update!(game_word_id: theirs)
      other_call.update!(game_word_id: ours)
    end
  end

  # Substitute a word from the library that is not yet part of the game.
  # The GameWord row is updated in place, so every board square follows.
  def replace_word(word)
    raise WordLocked unless word_changeable?

    game_word.update!(word: word, label: word.label)
  end

  # The core interaction: a newsletter click claims today's square.
  # Idempotent and concurrency-safe at every step.
  def claim_by(participant)
    raise NotClaimable unless claimable_now?

    board = participant.board_for(game)
    claim = daily_claims.create_or_find_by!(participant: participant) do |c|
      c.game = game
      c.claimed_at = Time.current
    end
    board.register_claim(self)
    claim
  end

  def link?
    link_url.present?
  end

  def prize_call?
    prize_call
  end

  def record_link_click
    self.class.where(id: id).update_all("link_clicks_count = link_clicks_count + 1")
  end
end
