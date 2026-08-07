class Publication < ApplicationRecord
  COLOR_FORMAT = /\A#\h{6}\z/

  belongs_to :account
  # Declaration order doubles as destroy order: games (and their words,
  # calls, boards) go before the word library and sponsors they reference.
  has_many :participants, dependent: :destroy
  has_many :games, dependent: :destroy
  has_many :sponsors, dependent: :destroy
  has_many :words, dependent: :destroy
  has_one_attached :logo

  scope :active, -> { where(active: true) }

  normalizes :name, with: ->(n) { n.strip }
  normalizes :slug, with: ->(s) { s.strip.downcase.gsub(/[^a-z0-9\-]+/, "-").gsub(/\A-+|-+\z/, "") }
  normalizes :email_merge_tag, with: ->(t) { t.strip }

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/ },
    uniqueness: { scope: :account_id }
  validates :public_code, presence: true, uniqueness: true
  validates :email_merge_tag, presence: true
  validates :primary_color, :accent_color, :background_color, :text_color,
    format: { with: COLOR_FORMAT, message: "must be a hex color like #1A2B3C" }
  validate :timezone_must_be_recognized

  before_validation :assign_public_code, on: :create

  def tz
    ActiveSupport::TimeZone[timezone]
  end

  def local_time
    Time.current.in_time_zone(tz)
  end

  def local_date
    local_time.to_date
  end

  # The one game currently accepting play, if any.
  def active_game
    games.active.first
  end

  # The game being set up or played; used by the admin dashboard.
  def open_game
    games.open.first
  end

  def todays_call
    active_game&.call_for(local_date)
  end

  # Games whose 24 days have elapsed roll over to completed lazily.
  def close_finished_games
    games.active.each { |game| game.complete if game.over? }
  end

  def analytics
    @analytics ||= Analytics.new(self)
  end

  # Word pool this publication can draw from when building a game.
  def eligible_words
    Word.active.where(publication_id: [ nil, id ])
  end

  def custom_words
    words
  end

  private
    def assign_public_code
      self.public_code ||= "pub_#{SecureRandom.base58(20)}"
    end

    def timezone_must_be_recognized
      if timezone.blank? || ActiveSupport::TimeZone[timezone].nil?
        errors.add(:timezone, "is not a recognized timezone")
      end
    end
end
