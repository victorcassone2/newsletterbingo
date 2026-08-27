class Publication < ApplicationRecord
  include Billable

  COLOR_FORMAT = /\A#\h{6}\z/

  belongs_to :account
  # Declaration order doubles as destroy order: games (and their awards)
  # go before the prizes and word library they reference.
  has_many :participants, dependent: :destroy
  has_many :games, dependent: :destroy
  has_many :prizes, dependent: :destroy
  has_many :words, dependent: :destroy
  has_one :line_prize, -> { where(kind: "line") }, class_name: "Prize", inverse_of: :publication
  has_one :blackout_prize, -> { where(kind: "blackout") }, class_name: "Prize", inverse_of: :publication
  has_one :closure, class_name: "PublicationClosure", dependent: :destroy
  has_one_attached :logo

  # active is the publisher's live/paused switch; canceling is the harder
  # stop, taking the publication off the subscription and, once the paid
  # period runs out, off the air.
  scope :active, -> { where(active: true) }
  scope :uncanceled, -> { where.missing(:closure) }
  # Everything a reader can reach: switched on, and either never canceled or
  # still inside the period its cancellation paid for.
  scope :playable, -> {
    active.left_joins(:closure)
      .where("publication_closures.id IS NULL OR publication_closures.closes_at > ?", Time.current)
  }

  normalizes :name, with: ->(n) { n.strip }
  normalizes :sponsor_name, with: ->(n) { n.strip }
  normalizes :email_merge_tag, with: ->(t) { t.strip }
  normalizes :campaign_merge_tag, with: ->(t) { t.strip }
  normalizes :primary_color, :accent_color, :background_color, :text_color,
    with: ->(color) { color.strip.downcase }

  validates :name, presence: true
  validates :public_code, presence: true, uniqueness: true
  validates :email_merge_tag, presence: true
  validates :board_size, inclusion: { in: Game::FORMATS.keys }
  validates :primary_color, :accent_color, :background_color, :text_color,
    format: { with: COLOR_FORMAT, message: "must be a hex color like #1A2B3C" }
  validate :timezone_must_be_recognized

  before_validation :assign_public_code, on: :create
  after_create :create_default_prizes
  after_update :reformat_draft_game, if: :saved_change_to_board_size?

  # Platforms that stamp a campaign id per send let us prove a click came
  # from the current email. Substack and Ghost don't, so those publications
  # advance on the first click after a quiet period instead.
  def campaign_tagged?
    campaign_merge_tag.present?
  end

  # Canceled: off the subscription, with a date it goes dark.
  def canceled?
    closure.present?
  end

  # Dark: canceled, and the period it was paid for has run out.
  def closed?
    canceled? && closure.effective?
  end

  def closes_on
    closure&.closes_at&.to_date
  end

  # Cancels one publication without disturbing the account's others. It comes
  # off the subscription now and stays on the air until the end of the period
  # already paid for. Nothing is destroyed, so restoring picks up boards,
  # claims and games where they were.
  def close
    create_closure!(closes_at: account.paid_through || Time.current) unless canceled?
  end

  # Reloads the association so a publication canceled and restored in the
  # same breath doesn't answer canceled? from a record that's already gone.
  def reopen
    closure&.destroy
    reload_closure
  end

  # Words per game under the publication's chosen format.
  def pool_size
    Game.pool_size_for(board_size)
  end

  # Squares on a card under the chosen format, excluding the FREE center.
  def board_cells
    board_size * board_size - 1
  end

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

  # The draft waiting to launch when the active game ends.
  def on_deck_game
    games.draft.first
  end

  # The one word readers can claim right now.
  def current_call
    active_game&.current_call
  end

  # Keeps the games carousel turning: finished games complete, the
  # on-deck draft launches in their place, and a fresh draft goes on
  # deck. Idempotent and safe to run concurrently: the partial unique
  # indexes on games referee every race. The first-ever game is only
  # drafted, never auto-launched; the publisher reviews and launches it.
  # A lapsed subscription blocks only the launch: the running game plays
  # out, drafts keep drafting, and readers hit the existing "no game
  # running" soft landing rather than a paywall.
  def rotate_games
    games.active.each { |game| game.complete if game.over? }
    launch_on_deck_game if billing_active? && games.active.none? && games.completed.exists?
    draft_on_deck_game if games.draft.none?
  end

  # The most recently finished game.
  def previous_game
    games.completed.order(starts_on: :desc, created_at: :desc).first
  end

  # Word ids the previous game used, so the next selection can avoid them.
  def recent_word_ids
    previous_game&.game_words&.pluck(:word_id) || []
  end

  # The call an already-recorded issue token resolved to, in any game.
  def issued_call_for(token)
    Issue.joins(:game).where(games: { publication_id: id }).find_by(token: token)&.daily_call
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

    # Every publication owns its standing prize pair from day one; the
    # Sponsors & Prizes page only ever enables, disables, and edits them.
    def create_default_prizes
      prizes.create!(kind: "line")
      prizes.create!(kind: "blackout")
    end

    # A format change applies to the next game, never one in progress:
    # the on-deck draft picks up the new shape and redraws its words.
    def reformat_draft_game
      game = games.draft.first
      return if game.nil?

      game.update!(board_size: board_size, pool_size: pool_size)
      begin
        game.regenerate_words
      rescue ArgumentError
        # Word pool too small for the new format; the Today screen flags
        # the short draft for the publisher.
      end
    end

    def launch_on_deck_game
      game = games.draft.first || draft_on_deck_game
      game.launch
    rescue Game::NotLaunchable, ActiveRecord::RecordNotUnique
      # A concurrent request launched a game first; the slot is taken.
    end

    def draft_on_deck_game
      game = games.create!(starts_on: next_game_starts_on)
      begin
        game.regenerate_words
      rescue ArgumentError
        # Word pool too small for a full set; leave the word-less draft
        # for the publisher to fill rather than fail a reader's request.
      end
      game
    rescue ActiveRecord::RecordNotUnique
      games.draft.first
    end

    def next_game_starts_on
      [ games.active.first&.ends_on&.succ, local_date ].compact.max
    end
end
