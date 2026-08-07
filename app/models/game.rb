class Game < ApplicationRecord
  DAYS = 24

  class NotLaunchable < StandardError; end

  belongs_to :publication
  # Declaration order doubles as destroy order: claims and awards first,
  # then boards and calls, and only then the words they all reference.
  has_many :daily_claims, dependent: :destroy
  has_many :prize_awards, dependent: :destroy
  has_many :bingo_boards, dependent: :destroy
  has_many :daily_calls, -> { order(:call_on) }, dependent: :destroy, inverse_of: :game
  has_many :prizes, dependent: :destroy
  has_many :game_words, -> { order(:created_at) }, dependent: :destroy, inverse_of: :game
  has_one :line_prize, -> { where(kind: "line") }, class_name: "Prize", inverse_of: :game
  has_one :blackout_prize, -> { where(kind: "blackout") }, class_name: "Prize", inverse_of: :game

  scope :open, -> { where(status: %w[ draft active ]) }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  validates :name, presence: true
  validates :starts_on, presence: true
  validates :status, inclusion: { in: %w[ draft active completed ] }

  before_validation :align_ends_on

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

  # Launching creates the game's 24 daily calls up front, one per local
  # calendar date, with the words in random order.
  def launch
    transaction do
      raise NotLaunchable, "game is already #{status}" unless draft?
      raise NotLaunchable, "a game needs exactly #{DAYS} words" unless game_words.count == DAYS

      update!(status: "active")
      schedule = game_words.to_a.shuffle(random: SecureRandom)
      schedule.each_with_index do |game_word, index|
        daily_calls.create!(game_word: game_word, call_on: starts_on + index)
      end
    end
  end

  def complete
    update!(status: "completed") if active?
  end

  def over?(date = publication.local_date)
    date > ends_on
  end

  def started?(date = publication.local_date)
    date >= starts_on
  end

  def in_window?(date)
    date.between?(starts_on, ends_on)
  end

  # 1-based day number for a date, nil outside the 24-day window.
  def day_number(date = publication.local_date)
    in_window?(date) ? (date - starts_on).to_i + 1 : nil
  end

  def days_elapsed(date = publication.local_date)
    ((date - starts_on).to_i + 1).clamp(0, DAYS)
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
    daily_calls.where(call_on: (date + 1)..)
  end

  private
    def align_ends_on
      self.ends_on = starts_on + (DAYS - 1) if starts_on.present?
    end
end
