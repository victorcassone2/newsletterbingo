require "test_helper"

class ClaimFlowTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
    @call = @game.call_for(@publication.local_date)
  end

  test "the newsletter click itself performs the claim and redirects to a clean URL" do
    get claim_path(@publication.public_code, email: "reader@example.com")

    assert_redirected_to board_path(@publication.public_code)
    assert_no_match(/reader/, response.headers["Location"])
    assert_no_match(/@/, response.headers["Location"])

    participant = @publication.participants.find_by(email: "reader@example.com")
    assert participant.present?
    assert_equal 1, participant.daily_claims.count
    assert participant.bingo_boards.exists?(game: @game)

    follow_redirect!
    assert_response :success
    assert_select ".claim-check", text: /claimed/
    assert_select ".square.claimed", count: 1
    assert_select "button", text: /Claim/, count: 0 # no second claim button anywhere
  end

  test "the board page never contains the raw email" do
    get claim_path(@publication.public_code, email: "reader@example.com")
    follow_redirect!
    assert_no_match(/reader@example\.com/, response.body)
  end

  test "repeat clicks are harmless" do
    2.times { get claim_path(@publication.public_code, email: "reader@example.com") }
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 1, participant.daily_claims.count
  end

  test "two subscribers get different boards over the same words" do
    get claim_path(@publication.public_code, email: "amy@example.com")
    get claim_path(@publication.public_code, email: "ben@example.com")

    amy = @publication.participants.find_by(email: "amy@example.com").board_for(@game)
    ben = @publication.participants.find_by(email: "ben@example.com").board_for(@game)
    assert_not_equal amy.bingo_squares.sort_by(&:position).map(&:game_word_id),
      ben.bingo_squares.sort_by(&:position).map(&:game_word_id)
    assert_equal amy.bingo_squares.filter_map(&:game_word_id).sort,
      ben.bingo_squares.filter_map(&:game_word_id).sort
  end

  test "missing email shows a friendly error" do
    get claim_path(@publication.public_code)
    assert_response :unprocessable_entity
    assert_select ".unavailable-card"
  end

  test "an unreplaced merge tag shows a configuration hint" do
    get claim_path(@publication.public_code, email: "{{email}}")
    assert_response :unprocessable_entity
    assert_match(/merge tag/, response.body)
  end

  test "malformed email shows a friendly error" do
    get claim_path(@publication.public_code, email: "not-an-email")
    assert_response :unprocessable_entity
  end

  test "unknown publication code 404s without Rails errors" do
    get claim_path("pub_does_not_exist", email: "reader@example.com")
    assert_response :not_found
    assert_select ".unavailable-card"
  end

  test "inactive publications do not accept claims" do
    @publication.update!(active: false)
    get claim_path(@publication.public_code, email: "reader@example.com")
    assert_response :not_found
  end

  test "no active game shows a friendly message" do
    @game.complete
    get claim_path(@publication.public_code, email: "reader@example.com")
    assert_response :not_found
    assert_match(/no bingo game running/i, response.body)
  end

  test "a game that hasn't started yet says so" do
    @game.destroy!
    create_running_game(@publication, starts_on: @publication.local_date + 3)
    get claim_path(@publication.public_code, email: "reader@example.com")
    assert_response :not_found
    assert_match(/starts/i, response.body)
  end

  test "a finished game refuses claims and completes itself" do
    game = @game
    game.update_columns(starts_on: @publication.local_date - 30, ends_on: @publication.local_date - 7)
    get claim_path(@publication.public_code, email: "reader@example.com")
    assert_response :not_found
    assert game.reload.completed?
    assert_equal 0, @publication.participants.where(email: "reader@example.com").count
  end

  test "celebration flash fires when the claim completes a bingo line" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    board = participant.board_for(@game)
    todays_square = board.square_for(@call.game_word)
    line = BingoBoard::LINES.detect { |l| l.include?(todays_square.position) && !l.include?(12) }
    (line - [ todays_square.position ]).each do |position|
      board.square_at(position).update!(claimed_at: 1.day.ago)
    end

    get claim_path(@publication.public_code, email: "reader@example.com")
    follow_redirect!
    assert_select ".celebration", text: /BINGO/
  end
end
