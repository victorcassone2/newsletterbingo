class Game < ApplicationRecord
  # The game formats, chosen on the publication and snapshotted here at
  # draft time: board size => how many words the game calls. Every pool
  # word gets called, but each card holds only board_cells of them, so
  # some calls miss some cards. That's what makes it bingo.
  FORMATS = { 5 => 30, 4 => 20, 3 => 12 }
  # Minimum gap between word advances, and how long the final word stays
  # claimable before the game completes.
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
  validates :board_size, inclusion: { in: FORMATS.keys }
  validates :pool_size, presence: true

  before_validation :assign_format, on: :create
  before_validation :align_ends_on

  # Picks `count` words for a new game: the publication's own words
  # first, topped up with system words, in random order. Custom words win
  # label collisions with system words. Words in `avoiding` (typically
  # the previous game's) sort behind fresh ones within each tier, so
  # repeats only happen when a tier's pool runs short.
  def self.random_word_selection(publication, count:, avoiding: [])
    avoided = avoiding.to_set
    fresh, recent = publication.words.active.to_a.shuffle(random: SecureRandom)
      .partition { |word| avoided.exclude?(word.id) }
    custom = (fresh + recent).first(count)
    return custom if custom.size == count

    taken_labels = custom.map { |w| w.label.downcase }
    pool = Word.system.active
    pool = pool.where.not("lower(label) IN (?)", taken_labels) if taken_labels.any?
    fresh, recent = pool.to_a.shuffle(random: SecureRandom)
      .partition { |word| avoided.exclude?(word.id) }
    custom + (fresh + recent).first(count - custom.size)
  end

  def self.pool_size_for(board_size)
    FORMATS.fetch(board_size)
  end

  # An odd board has a middle square, and that square plays FREE. An even
  # board has no middle, so every square on it carries a word.
  def self.free_center?(board_size)
    board_size.odd?
  end

  def draft? = status == "draft"
  def active? = status == "active"
  def completed? = status == "completed"

  # Squares on a card, excluding the FREE center on formats that have one.
  def board_cells
    board_size * board_size - (free_center? ? 1 : 0)
  end

  def free_center?
    self.class.free_center?(board_size)
  end

  # Replaces the draft game's word set. Labels are snapshotted so later
  # edits to the library never rewrite game history. Each word gets an
  # undated call up front, so the publisher can write call content and
  # reorder the schedule before launch, exactly like a live game.
  def assign_words(words)
    raise NotLaunchable, "words are locked once a game launches" unless draft?
    raise ArgumentError, "a game needs exactly #{pool_size} unique words" unless words.map(&:id).uniq.size == pool_size

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
    assign_words(self.class.random_word_selection(publication, count: pool_size,
      avoiding: publication.recent_word_ids))
  end

  # Launching fixes the draft's call order as the calling order. Every call
  # gets its date when its newsletter actually goes out, so the span the
  # game carries from here is only an estimate.
  def launch
    transaction do
      # Row-lock and re-check status so concurrent launches serialize;
      # the loser sees "active" and backs off.
      locked_status = self.class.lock.find(id).status
      raise NotLaunchable, "game is already #{locked_status}" unless locked_status == "draft"
      raise NotLaunchable, "a game needs exactly #{pool_size} words" unless game_words.count == pool_size

      update!(status: "active")
      ensure_calls_drafted
      update!(starts_on: publication.local_date, ends_on: publication.local_date + pool_size - 1)
    end
  end

  def complete
    update!(status: "completed") if active?
  end

  # The one claimable call right now: the most recently issued word.
  def current_call
    issued_calls.last
  end

  # The word queued to go out with the next send. Nil once the last word
  # is out.
  def next_call
    daily_calls.find_by(call_on: nil)
  end

  # Resolves the call a claim link's token authorizes. Any value that
  # survived its platform's replacement proves which send it came from,
  # whether it rode in the publication's own merge tag or was stamped
  # into the link by the platform itself. A tagged publication whose link
  # carried nothing usable proves nothing and claims nothing; an untagged
  # one infers the send from how long it has been quiet instead.
  def claimable_call_for(candidate)
    token = candidate.to_s.strip
    if Issue.plausible_token?(token)
      claimable_by_token(token)
    elsif publication.campaign_tagged?
      nil
    else
      claimable_by_interval
    end
  end

  def issued_calls
    daily_calls.where.not(call_on: nil)
  end

  def over?(date = publication.local_date)
    last_issued = issued_calls.last
    daily_calls.any? && daily_calls.where(call_on: nil).none? &&
      last_issued.call_on < date - LAST_ISSUE_OPEN_FOR
  end

  def started?
    issued_calls.exists?
  end

  def in_window?(date)
    date.between?(starts_on, ends_on)
  end

  # Position of the latest issued word. Nil before the game produces one.
  def day_number
    issued_calls.last&.position
  end

  def days_elapsed(date = publication.local_date)
    called_calls(date).count
  end

  def days_remaining(date = publication.local_date)
    pool_size - days_elapsed(date)
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
    # New drafts inherit the publication's chosen format; both numbers
    # are snapshotted so a later settings change never reshapes a game
    # already in front of readers.
    def assign_format
      self.board_size ||= publication&.board_size || FORMATS.keys.first
      self.pool_size ||= FORMATS[board_size]
    end

    # Drafts carry an estimated end date off their estimated start; launch
    # re-estimates it from the real launch day, which later saves must not
    # clobber. Only the words going out settle the real span.
    def align_ends_on
      self.ends_on = starts_on + (pool_size - 1) if starts_on.present? && pool_size.present? && draft?
    end

    # Drafts carry their undated calls from assign_words; rebuild them for
    # drafts that predate calls existing at draft time.
    def ensure_calls_drafted
      return if daily_calls.count == pool_size

      daily_calls.destroy_all
      game_words.each { |game_word| daily_calls.create!(game_word: game_word, position: game_word.position) }
    end

    # The token gate is what separates playing from viewing: a bookmarked
    # or stale link still opens the board, but only the current email's
    # button claims. The first sight of an unseen token advances the game.
    # Tokens already recorded on an earlier call or game are stale.
    def claimable_by_token(token)
      return nil unless Issue.plausible_token?(token)

      issue = issues.find_by(token: token)
      if issue
        issue.daily_call if issue.daily_call == current_call
      elsif publication.issued_call_for(token)
        nil # an older send's token resolves to history, never a new claim
      else
        advance_to_next_word(token)
      end
    rescue ActiveRecord::RecordNotUnique
      # Lost a same-token race: the winner recorded it, so resolve theirs.
      issue = issues.find_by(token: token)
      issue.daily_call if issue && issue.daily_call == current_call
    end

    # Without a campaign id, a send is inferred rather than proven: the
    # first click after the interval floor draws the next word. Every later
    # click in that send resolves to the same word and claims it, so
    # readers who open hours later still play.
    def claimable_by_interval
      if issue_floor_elapsed?
        advance_to_next_word(SecureRandom.uuid) || current_call
      else
        current_call
      end
    end

    def issue_floor_elapsed?
      last = issues.order(:created_at).last
      last.nil? || last.created_at <= ISSUE_INTERVAL_FLOOR.ago
    end

    # The first sight of a new send's token issues the next word. The
    # game row lock serializes concurrent advances: a racing loser
    # re-checks the interval floor, sees the winner's fresh issue, and
    # backs off without claiming.
    def advance_to_next_word(token)
      advanced = nil
      exhausted = false
      transaction do
        lock!
        if issue_floor_elapsed?
          advanced = daily_calls.find_by(call_on: nil)
          if advanced
            issues.create!(token: token, daily_call: advanced, called_on: publication.local_date)
            advanced.update!(call_on: publication.local_date)
          else
            exhausted = true
          end
        end
      end
      exhausted ? roll_into_successor(token) : advanced
    end

    # A plausible new token with no words left to issue is the next send
    # after the game's last word: it completes this game, and the same
    # token draws word 1 of the successor.
    def roll_into_successor(token)
      complete
      publication.rotate_games
      successor = publication.active_game
      if successor && successor != self
        successor.claimable_call_for(token)
      end
    end
end
