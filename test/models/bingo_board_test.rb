require "test_helper"

class BingoBoardTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
    @participant = Participant.locate_or_register(@publication, "reader@example.com")
  end

  test "a classic board is a 5x5 grid with a FREE center and 24 of the game's 30 words" do
    board = @participant.board_for(@game)
    assert_equal 25, board.bingo_squares.count
    assert board.square_at(12).free?
    assert_equal "FREE", board.square_at(12).label

    dealt = board.bingo_squares.filter_map(&:game_word_id)
    assert_equal 24, dealt.size
    assert_equal 24, dealt.uniq.size
    assert_empty dealt - @game.game_words.pluck(:id)
  end

  test "a quick board is a 3x3 grid with a FREE center and 8 of the game's 12 words" do
    publication = publications(:lincoln)
    publication.update!(board_size: 3)
    game = create_running_game(publication)
    participant = Participant.locate_or_register(publication, "reader@example.com")
    board = participant.board_for(game)

    assert_equal 9, board.bingo_squares.count
    assert board.square_at(4).free?

    dealt = board.bingo_squares.filter_map(&:game_word_id)
    assert_equal 8, dealt.size
    assert_empty dealt - game.game_words.pluck(:id)
    assert_equal 12, game.game_words.count
  end

  test "a compact board is a 4x4 grid with no FREE square and 16 of the game's 20 words" do
    publication = publications(:lincoln)
    publication.update!(board_size: 4)
    game = create_running_game(publication)
    participant = Participant.locate_or_register(publication, "reader@example.com")
    board = participant.board_for(game)

    assert_equal 16, board.bingo_squares.count
    assert_nil board.center
    assert_not board.bingo_squares.any?(&:free?)

    dealt = board.bingo_squares.filter_map(&:game_word_id)
    assert_equal 16, dealt.size
    assert_equal 16, dealt.uniq.size
    assert_empty dealt - game.game_words.pluck(:id)
    assert_equal 20, game.game_words.count
  end

  test "a compact board takes a blackout only once every square is claimed" do
    publication = publications(:lincoln)
    publication.update!(board_size: 4)
    game = create_running_game(publication)
    participant = Participant.locate_or_register(publication, "reader@example.com")
    board = participant.board_for(game)

    board.bingo_squares.order(:position).each_with_index do |square, index|
      square.update!(claimed_at: Time.current)
      assert_equal index == 15, board.reload.blackout?
    end
  end

  test "one board per participant per game" do
    board = @participant.board_for(@game)
    assert_equal board, @participant.board_for(@game)
    assert_equal 1, @participant.bingo_boards.where(game: @game).count
  end

  test "duplicate boards are impossible at the database level" do
    @participant.board_for(@game)
    assert_raises(ActiveRecord::RecordNotUnique) do
      BingoBoard.new(participant: @participant, game: @game).save!(validate: false)
    end
  end

  test "two participants almost always get different arrangements" do
    other = Participant.locate_or_register(@publication, "other@example.com")
    layouts = [ @participant, other ].map do |participant|
      participant.board_for(@game).bingo_squares.sort_by(&:position).map(&:game_word_id)
    end
    assert_not_equal layouts.first, layouts.last
  end

  test "a board is persisted and never reshuffles" do
    layout = @participant.board_for(@game).bingo_squares.sort_by(&:position).map(&:game_word_id)
    3.times do
      reloaded = @participant.reload.board_for(@game).bingo_squares.sort_by(&:position).map(&:game_word_id)
      assert_equal layout, reloaded
    end
  end

  test "square positions and words are unique per board" do
    board = @participant.board_for(@game)
    square = board.bingo_squares.detect { |s| s.position == 0 }
    duplicate_position = BingoSquare.new(bingo_board: board, game_word: @game.game_words.first, position: 0)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate_position.save!(validate: false) }

    duplicate_word = BingoSquare.new(bingo_board: board, game_word: square.game_word, position: 3)
    assert_raises(ActiveRecord::RecordNotUnique) do
      BingoSquare.where(bingo_board: board, position: 3).delete_all
      duplicate_word.save!(validate: false)
    end
  end

  test "only the center can be FREE" do
    board = @participant.board_for(@game)
    BingoSquare.where(bingo_board: board, position: 3).delete_all
    square = BingoSquare.new(bingo_board: board, position: 3, game_word: nil)
    assert_not square.valid?
    assert square.errors[:game_word].any?
  end

  test "line geometry adapts to the board size" do
    assert_equal 12, BingoBoard.lines_for(5).size
    assert_includes BingoBoard.lines_for(5), [ 0, 6, 12, 18, 24 ]
    assert_equal 8, BingoBoard.lines_for(3).size
    assert_includes BingoBoard.lines_for(3), [ 0, 4, 8 ]
    assert_includes BingoBoard.lines_for(3), [ 2, 4, 6 ]
  end

  test "rows, columns, and both diagonals complete a bingo, with FREE counting" do
    [ [ 5, 6, 7, 8, 9 ],            # row 2
      [ 1, 6, 11, 16, 21 ],         # column 2
      [ 0, 6, 12, 18, 24 ],         # main diagonal (through FREE)
      [ 4, 8, 12, 16, 20 ] ].each do |line|
      board = fresh_board
      line.each do |position|
        square = board.square_at(position)
        square.update!(claimed_at: Time.current) unless square.free?
      end
      assert board.bingo?, "expected bingo for line #{line.inspect}"
      board.bingo_squares.reload
    end
  end

  test "no false positive bingo" do
    board = fresh_board
    [ 0, 1, 2, 3, 5 ].each do |position| # four in a row plus a stray
      board.square_at(position).update!(claimed_at: Time.current)
    end
    assert_not board.bingo?
  end

  test "blackout requires every playable square on the card" do
    board = fresh_board
    playable = board.bingo_squares.reject(&:free?)
    playable.first(playable.size - 1).each { |square| square.update!(claimed_at: Time.current) }
    assert_not board.blackout?

    playable.last.update!(claimed_at: Time.current)
    assert board.blackout?
  end

  test "a call whose word is off the card registers nothing but stays safe" do
    board = @participant.board_for(@game)
    dealt = board.bingo_squares.filter_map(&:game_word_id).to_set
    off_card_call = @game.daily_calls.detect { |call| dealt.exclude?(call.game_word_id) }
    assert off_card_call, "a 24-cell board of a 30-word pool always misses some words"
    assert_not board.covers?(off_card_call.game_word)

    board.register_claim(off_card_call)
    assert_equal 0, board.claimed_word_count
  end

  test "refresh_achievements records first bingo exactly once" do
    board = fresh_board
    (0..4).each { |position| board.square_at(position).update!(claimed_at: Time.current) }
    board.refresh_achievements
    first_time = board.reload.bingo_achieved_at
    assert first_time.present?

    travel 1.hour do
      (5..9).each { |position| board.square_at(position).update!(claimed_at: Time.current) }
      board.refresh_achievements
      assert_equal first_time, board.reload.bingo_achieved_at
    end
  end

  private
    def fresh_board
      participant = Participant.locate_or_register(@publication, "board-#{SecureRandom.hex(4)}@example.com")
      participant.board_for(@game)
    end
end
