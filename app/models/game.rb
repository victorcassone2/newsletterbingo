class Game < ApplicationRecord
  DAYS = 24
  # Issue cadence: minimum gap between word advances, and how long the
  # final word stays claimable before the game completes.
  ISSUE_INTERVAL_FLOOR = 12.hours
  LAST_ISSUE_OPEN_FOR = 7 # days

  class NotLaunchable < StandardError; end

  belongs_to :publication
  # Declaration order doubles as destroy order: claims and awards first,
  # then boards and calls, and only then the words they all reference.
  has_many :daily_claims, dependent: :destroy
  has_many :prize_awards, dependent: :destroy
  has_many :bingo_boards, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :daily_calls, -> { order(:position) }, dependent: :destroy, inverse_of: :game
  has_many :game_words, -> { order(:position) }, dependent: :destroy, inverse_of: :game

  scope :open, -> { where(status: %w[ draft active ]) }
  scope :draft, -> { where(status: "draft") }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  validates :starts_on, presence: true
  validates :status, inclusion: { in: %w[ draft active completed ] }

  before_validation :align_ends_on

  delegate :issue_cadence?, :calendar_cadence?, to: :publication

  # Picks 24 words for a new game: the publication's own words first,
  # topped up with system words, in random order. Custom words win label
  # collisions with system words. Words in `avoiding` (typically the
  # previous game's) sort behind fresh ones within each tier, so repeats
  # only happen when a tier's pool runs short.
  def self.random_word_selection(publication, avoiding: [])
    avoided = avoiding.to_set
    fresh, recent = publication.words.active.to_a.shuffle(random: SecureRandom)
      .partition { |word| avoided.exclude?(word.id) }
    custom = (fresh + recent).first(DAYS)
    return custom if custom.size == DAYS

    taken_labels = custom.map { |w| w.label.downcase }
    pool = Word.system.active
    pool = pool.where.not("lower(label) IN (?)", taken_labels) if taken_labels.any?
    fresh, recent = pool.to_a.shuffle(random: SecureRandom)
      .partition { |word| avoided.exclude?(word.id) }
    custom + (fresh + recent).first(DAYS - custom.size)
  end

  def draft? = status == "draft"
  def active? = status == "active"
  def completed? = status == "completed"

  # Replaces the draft game's word set. Labels are snapshotted so later
  # edits to the library never rewrite game history. Each word gets an
  # undated call up front, so the publisher can write call content and
  # reorder the schedule before launch, exactly like a live game.
  def assign_words(words)
    raise NotLaunchable, "words are locked once a game launches" unless draft?
    raise ArgumentError, "a game needs exactly #{DAYS} unique words" unless words.map(&:id).uniq.size == DAYS

    transaction do
      daily_calls.destroy_all
      game_words.destroy_all
      words.each_with_index do |word, index|
        game_word = game_words.create!(word: word, label: word.label, position: index + 1)
        daily_calls.create!(game_word: game_word, position: index + 1)
      end
    end
  end

  def regenerate_words
    assign_words(self.class.random_word_selection(publication, avoiding: publication.recent_word_ids))
  end

  # Launching fixes the draft's call order as the calling order. Calendar
  # games get their 24 dates up front (on the publication's send days);
  # issue games date each call when its newsletter actually goes out. A
  # draft can sit on deck long past its estimated start, so dates are
  # clamped to begin no earlier than today.
  def launch
    transaction do
      # Row-lock and re-check status so concurrent launches serialize;
      # the loser sees "active" and backs off.
      locked_status = self.class.lock.find(id).status
      raise NotLaunchable, "game is already #{locked_status}" unless locked_status == "draft"
      raise NotLaunchable, "a game needs exactly #{DAYS} words" unless game_words.count == DAYS

      update!(status: "active")
      ensure_calls_drafted
      if calendar_cadence?
        dates = scheduled_dates(from: [ starts_on, publication.local_date ].max)
        daily_calls.reload.each_with_index { |call, index| call.update!(call_on: dates[index]) }
        update!(starts_on: dates.first, ends_on: dates.last)
      else
        update!(starts_on: publication.local_date, ends_on: publication.local_date + DAYS - 1)
      end
    end
  end

  def complete
    update!(status: "completed") if active?
  end

  # Adapts an in-flight game when the publication switches cadence. Words
  # that already went out keep their dates; the rest go back to the
  # unissued queue (issues) or onto upcoming send days (calendar).
  def reschedule_for_cadence
    return unless active?

    if issue_cadence?
      daily_calls.where(call_on: (publication.local_date + 1)..).update_all(call_on: nil)
    else
      transaction do
        pending = daily_calls.where(call_on: nil).to_a
        scheduled_dates(from: publication.local_date + 1, count: pending.size).each_with_index do |date, index|
          pending[index].update!(call_on: date)
        end
        update!(starts_on: daily_calls.minimum(:call_on), ends_on: daily_calls.maximum(:call_on))
      end
    end
  end

  # The one claimable call right now: today's scheduled word (calendar)
  # or the most recently issued word (issues).
  def current_call
    if issue_cadence?
      issued_calls.last
    else
      call_for(publication.local_date)
    end
  end

  # The word queued to go out after the current one: next in the unissued
  # queue (issues) or the next dated call (calendar). Nil once the last
  # word is out.
  def next_call
    if issue_cadence?
      daily_calls.find_by(call_on: nil)
    else
      daily_calls.where(call_on: (publication.local_date + 1)..).first
    end
  end

  # Resolves the claimable call for a newsletter's issue token, advancing
  # to the next word the first time a plausible new token shows up. A
  # token already recorded on an earlier game resolves to the word that
  # email actually carried (no longer claimable), never a fresh advance.
  def call_for_issue(token)
    token = token.to_s.strip
    issue = issues.find_by(token: token)
    if issue
      issue.daily_call
    elsif (previous_call = publication.issued_call_for(token))
      previous_call
    elsif Issue.plausible_token?(token) && issue_floor_elapsed?
      advance_to_next_word(token)
    else
      current_call
    end
  end

  def issued_calls
    daily_calls.where.not(call_on: nil)
  end

  def over?(date = publication.local_date)
    if issue_cadence?
      last_issued = issued_calls.last
      daily_calls.any? && daily_calls.where(call_on: nil).none? &&
        last_issued.call_on < date - LAST_ISSUE_OPEN_FOR
    else
      date > ends_on
    end
  end

  def started?(date = publication.local_date)
    if issue_cadence?
      issued_calls.exists?
    else
      date >= starts_on
    end
  end

  def in_window?(date)
    date.between?(starts_on, ends_on)
  end

  # Position of the current word: the call on the given date (calendar)
  # or the latest issued call. Nil before the game produces one.
  def day_number(date = publication.local_date)
    if issue_cadence?
      issued_calls.last&.position
    else
      call_for(date)&.position
    end
  end

  def days_elapsed(date = publication.local_date)
    called_calls(date).count
  end

  def days_remaining(date = publication.local_date)
    DAYS - days_elapsed(date)
  end

  def call_for(date)
    daily_calls.find_by(call_on: date)
  end

  def called_calls(date = publication.local_date)
    daily_calls.where(call_on: ..date)
  end

  def upcoming_calls(date = publication.local_date)
    daily_calls.where(call_on: (date + 1)..).or(daily_calls.where(call_on: nil))
  end

  private
    # Drafts carry an estimated end date; launch replaces it with the real
    # schedule's last day, which later saves must not clobber.
    def align_ends_on
      self.ends_on = starts_on + (DAYS - 1) if starts_on.present? && draft?
    end

    # Drafts carry their undated calls from assign_words; rebuild them for
    # drafts that predate calls existing at draft time.
    def ensure_calls_drafted
      return if daily_calls.count == DAYS

      daily_calls.destroy_all
      game_words.each { |game_word| daily_calls.create!(game_word: game_word, position: game_word.position) }
    end

    # The next `count` dates on the publication's send days, starting no
    # earlier than `from`.
    def scheduled_dates(from: starts_on, count: DAYS)
      wdays = publication.sending_wdays
      dates = []
      date = from
      while dates.size < count
        dates << date if wdays.include?(date.wday)
        date += 1
      end
      dates
    end

    def issue_floor_elapsed?
      last = issues.order(:created_at).last
      last.nil? || last.created_at <= ISSUE_INTERVAL_FLOOR.ago
    end

    # A plausible new token with no words left to issue is the next send
    # after the game's last word: it rolls the games over, and the same
    # token draws word 1 of the successor.
    def advance_to_next_word(token)
      next_call = daily_calls.find_by(call_on: nil)
      if next_call.nil?
        complete
        publication.rotate_games
        successor = publication.active_game
        if successor && successor != self
          successor.call_for_issue(token)
        else
          current_call
        end
      else
        transaction do
          issues.create!(token: token, daily_call: next_call, called_on: publication.local_date)
          next_call.update!(call_on: publication.local_date)
        end
        next_call
      end
    rescue ActiveRecord::RecordNotUnique
      issues.find_by(token: token)&.daily_call || current_call
    end
end
