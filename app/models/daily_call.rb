class DailyCall < ApplicationRecord
  class NotClaimable < StandardError; end
  class WordLocked < StandardError; end

  belongs_to :game
  belongs_to :game_word
  has_many :daily_claims, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_one :publication, through: :game

  scope :chronological, -> { order(:position) }

  validates :position, presence: true, uniqueness: { scope: :game_id }
  validates :call_on, uniqueness: { scope: :game_id },
    if: -> { call_on.present? && game&.calendar_cadence? }
  validates :link_url, http_url: true
  validates :link_text, presence: true, if: -> { link_url.present? }
  validates :prize_description, presence: true, if: :prize_call?

  delegate :label, to: :game_word

  # Issue-cadence calls get their date the moment their newsletter goes out.
  def issued?
    call_on.present?
  end

  def claimable_now?
    game.active? && current?
  end

  # The one call readers can claim right now.
  def current?
    if game.issue_cadence?
      issued? && self == game.current_call
    else
      call_on == publication.local_date
    end
  end

  # A call is "called" once its date has arrived (or its issue went out).
  def called?(date = publication.local_date)
    issued? && call_on <= date
  end

  def today?(date = publication.local_date)
    call_on == date
  end

  def upcoming?(date = publication.local_date)
    !issued? || call_on > date
  end

  def day_number
    position
  end

  # This call's place in the unissued queue: 1 means it goes out with
  # the very next send. Nil once it has a date or before launch.
  def sends_away
    game.daily_calls.where(call_on: nil, position: ..position).count if game.active? && !issued?
  end

  # Once a word is out (called, claimed, or sent with an issue) it keeps
  # its place in game history. Draft calls are always still on the table.
  def word_changeable?
    if game.draft?
      true
    elsif game.issue_cadence?
      !issued?
    else
      call_on >= publication.local_date && daily_claims.none?
    end
  end

  # Moves this call's word to another slot in the upcoming schedule; the
  # words between the two slots shift by one to make room. Calls keep
  # their positions and dates. Only the word assignments rotate, so
  # issued history is never rewritten.
  def move_word_to(new_position)
    affected = game.daily_calls.where(position: [ position, new_position ].min..[ position, new_position ].max).to_a
    return if affected.size < 2
    raise WordLocked unless affected.all?(&:word_changeable?)

    transaction do
      words = affected.map(&:game_word_id).rotate(new_position > position ? 1 : -1)
      affected.each_with_index { |call, index| call.update!(game_word_id: words[index]) }
    end
  end

  # Substitute a word from the library that is not yet part of the game.
  # The GameWord row is updated in place, so every board square follows.
  def replace_word(word)
    raise WordLocked unless word_changeable?

    game_word.update!(word: word, label: word.label)
  end

  # The core interaction: a newsletter click claims the current square.
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
