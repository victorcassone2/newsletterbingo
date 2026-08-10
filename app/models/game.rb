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
  has_many :prizes, dependent: :destroy
  has_many :game_words, -> { order(:created_at) }, dependent: :destroy, inverse_of: :game
  has_one :line_prize, -> { where(kind: "line") }, class_name: "Prize", inverse_of: :game
  has_one :blackout_prize, -> { where(kind: "blackout") }, class_name: "Prize", inverse_of: :game

  normalizes :sponsor_name, with: ->(n) { n.strip }

  scope :open, -> { where(status: %w[ draft active ]) }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  validates :name, presence: true
  validates :starts_on, presence: true
  validates :status, inclusion: { in: %w[ draft active completed ] }

  before_validation :align_ends_on

  delegate :issue_cadence?, :calendar_cadence?, to: :publication

  # Picks 24 words for a new game: the publication's own words first,
  # topped up with system words, in random order. Custom words win label
  # collisions with system words.
  def self.random_word_selection(publication)
    custom = publication.words.active.to_a.shuffle(random: SecureRandom).first(DAYS)
    return custom if custom.size == DAYS

    taken_labels = custom.map { |w| w.label.downcase }
    pool = Word.system.active
    pool = pool.where.not("lower(label) IN (?)", taken_labels) if taken_labels.any?
    custom + pool.to_a.shuffle(random: SecureRandom).first(DAYS - custom.size)
  end

  def draft? = status == "draft"
  def active? = status == "active"
  def completed? = status == "completed"

  # Replaces the draft game's word set. Labels are snapshotted so later
  # edits to the library never rewrite game history.
  def assign_words(words)
    raise NotLaunchable, "words are locked once a game launches" unless draft?
    raise ArgumentError, "a game needs exactly #{DAYS} unique words" unless words.map(&:id).uniq.size == DAYS

    transaction do
      game_words.destroy_all
      words.each { |word| game_words.create!(word: word, label: word.label) }
    end
  end

  def regenerate_words
    assign_words(self.class.random_word_selection(publication))
  end

  # Launching fixes the words into a random calling order. Calendar games
  # get their 24 dates up front (on the publication's send days); issue
  # games date each call when its newsletter actually goes out.
  def launch
    transaction do
      raise NotLaunchable, "game is already #{status}" unless draft?
      raise NotLaunchable, "a game needs exactly #{DAYS} words" unless game_words.count == DAYS

      update!(status: "active")
      schedule = game_words.to_a.shuffle(random: SecureRandom)
      dates = calendar_cadence? ? scheduled_dates : []
      schedule.each_with_index do |game_word, index|
        daily_calls.create!(game_word: game_word, position: index + 1, call_on: dates[index])
      end
      update!(starts_on: dates.first, ends_on: dates.last) if dates.any?
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
  # to the next word the first time a plausible new token shows up.
  def call_for_issue(token)
    token = token.to_s.strip
    issue = issues.find_by(token: token)
    if issue
      issue.daily_call
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

    def advance_to_next_word(token)
      next_call = daily_calls.find_by(call_on: nil)
      if next_call.nil?
        complete
        current_call
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
