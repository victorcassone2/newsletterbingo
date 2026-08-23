class BingoBoard < ApplicationRecord
  CENTER = 12
  ROWS = (0..4).map { |r| (r * 5..r * 5 + 4).to_a }
  COLUMNS = (0..4).map { |c| [ c, c + 5, c + 10, c + 15, c + 20 ] }
  DIAGONALS = [ [ 0, 6, 12, 18, 24 ], [ 4, 8, 12, 16, 20 ] ]
  LINES = ROWS + COLUMNS + DIAGONALS

  belongs_to :participant
  belongs_to :game
  has_many :bingo_squares, -> { order(:position) }, dependent: :destroy, inverse_of: :bingo_board

  # Builds a participant's permanent board: the game's exact 24 words in a
  # securely shuffled arrangement around the FREE center. If two first
  # clicks race, the unique (participant, game) index makes one of them
  # adopt the other's board.
  def self.generate_for(participant, game)
    words = game.game_words.to_a
    raise ArgumentError, "game must have exactly #{Game::DAYS} words" unless words.size == Game::DAYS

    transaction do
      board = create!(participant: participant, game: game)
      shuffled = words.shuffle(random: SecureRandom)
      positions = (0..24).to_a - [ CENTER ]
      board.bingo_squares.create!(position: CENTER, game_word: nil)
      positions.each_with_index do |position, index|
        board.bingo_squares.create!(position: position, game_word: shuffled[index])
      end
      board
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(participant: participant, game: game)
  end

  # An unsaved board for publisher previews: the game's words in a stable
  # shuffled arrangement, with every word already out (through the given
  # call) marked claimed. Nothing is persisted and no participant exists.
  def self.sample_for(game, through: game.current_call)
    board = new(game: game)
    shuffled = game.game_words.includes(:daily_call).to_a
      .shuffle(random: Random.new(game.id.delete("-").to_i(16)))
    board.bingo_squares.build(position: CENTER, game_word: nil)
    ((0..24).to_a - [ CENTER ]).each_with_index do |position, index|
      word = shuffled[index]
      claimed = through && word.daily_call && word.daily_call.position <= through.position
      board.bingo_squares.build(position: position, game_word: word,
        claimed_at: (Time.current if claimed))
    end
    board
  end

  def square_at(position)
    bingo_squares.detect { |square| square.position == position }
  end

  def square_for(game_word)
    bingo_squares.detect { |square| square.game_word_id == game_word.id }
  end

  # Marks the square for a claimed call and re-evaluates bingo/blackout.
  # Safe to run repeatedly.
  def register_claim(daily_call)
    square = square_for(daily_call.game_word)
    square.update!(claimed_at: Time.current) if square && !square.claimed_at
    refresh_achievements
  end

  def claimed_positions
    bingo_squares.filter_map { |square| square.position if square.claimed? }.to_set
  end

  def completed_lines
    positions = claimed_positions
    LINES.select { |line| line.all? { |position| positions.include?(position) } }
  end

  def bingo?
    completed_lines.any?
  end

  def claimed_word_count
    bingo_squares.count { |square| !square.free? && square.claimed? }
  end

  def blackout?
    claimed_word_count == Game::DAYS
  end

  def bingo_achieved? = bingo_achieved_at.present?
  def blackout_achieved? = blackout_achieved_at.present?

  def refresh_achievements
    if bingo? && bingo_achieved_at.nil?
      update!(bingo_achieved_at: Time.current)
      game.publication.line_prize&.award_to(participant, game: game)
    end
    if blackout? && blackout_achieved_at.nil?
      update!(blackout_achieved_at: Time.current)
      game.publication.blackout_prize&.award_to(participant, game: game)
    end
  end
end
