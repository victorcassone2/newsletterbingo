class BingoBoard < ApplicationRecord
  belongs_to :participant
  belongs_to :game
  has_many :bingo_squares, -> { order(:position) }, dependent: :destroy, inverse_of: :bingo_board

  delegate :board_size, :board_cells, to: :game

  # Line geometry for a given board size: every row, every column, and
  # the two diagonals, as arrays of square positions.
  def self.lines_for(size)
    @lines ||= {}
    @lines[size] ||= begin
      rows = (0...size).map { |row| (row * size...(row + 1) * size).to_a }
      columns = (0...size).map { |column| rows.map { |row| row[column] } }
      diagonals = [ (0...size).map { |i| i * size + i },
                    (0...size).map { |i| i * size + (size - 1 - i) } ]
      (rows + columns + diagonals).map(&:freeze).freeze
    end
  end

  def self.center_for(size)
    (size * size - 1) / 2
  end

  # Builds a participant's permanent card: board_cells of the game's pool
  # words, securely dealt and shuffled around the FREE center. Cards hold
  # a subset of the pool, so no two cards play alike and not every call
  # lands on every card. If two first clicks race, the unique
  # (participant, game) index makes one of them adopt the other's board.
  def self.generate_for(participant, game)
    words = game.game_words.to_a
    raise ArgumentError, "game must have exactly #{game.pool_size} words" unless words.size == game.pool_size

    transaction do
      board = create!(participant: participant, game: game)
      dealt = words.shuffle(random: SecureRandom).first(game.board_cells)
      center = center_for(game.board_size)
      positions = (0...game.board_size**2).to_a - [ center ]
      board.bingo_squares.create!(position: center, game_word: nil)
      positions.each_with_index do |position, index|
        board.bingo_squares.create!(position: position, game_word: dealt[index])
      end
      board
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(participant: participant, game: game)
  end

  # An unsaved board for publisher previews: a stable dealt-and-shuffled
  # card from the game's pool, with every card word already out (through
  # the given call) marked claimed. Nothing is persisted and no
  # participant exists.
  def self.sample_for(game, through: game.current_call)
    board = new(game: game)
    dealt = game.game_words.includes(:daily_call).to_a
      .shuffle(random: Random.new(game.id.delete("-").to_i(16)))
      .first(game.board_cells)
    center = center_for(game.board_size)
    board.bingo_squares.build(position: center, game_word: nil)
    ((0...game.board_size**2).to_a - [ center ]).each_with_index do |position, index|
      word = dealt[index]
      claimed = through && word.daily_call && word.daily_call.position <= through.position
      board.bingo_squares.build(position: position, game_word: word,
        claimed_at: (Time.current if claimed))
    end
    board
  end

  def center
    self.class.center_for(board_size)
  end

  def lines
    self.class.lines_for(board_size)
  end

  def square_at(position)
    bingo_squares.detect { |square| square.position == position }
  end

  def square_for(game_word)
    bingo_squares.detect { |square| square.game_word_id == game_word.id }
  end

  # Whether a pool word was dealt onto this card.
  def covers?(game_word)
    square_for(game_word).present?
  end

  # Marks the square for a claimed call and re-evaluates bingo/blackout.
  # A call whose word isn't on this card marks nothing; the claim still
  # counts as attendance, the card just didn't get lucky today. Safe to
  # run repeatedly.
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
    lines.select { |line| line.all? { |position| positions.include?(position) } }
  end

  def bingo?
    completed_lines.any?
  end

  def claimed_word_count
    bingo_squares.count { |square| !square.free? && square.claimed? }
  end

  def blackout?
    claimed_word_count == board_cells
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
