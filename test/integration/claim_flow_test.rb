require "test_helper"

class ClaimFlowTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    # Nothing has gone out yet: the first click below is the send that
    # draws word 1.
    @game = create_running_game(@publication, issued: 0)
    @call = @game.daily_calls.first
  end

  test "a call's title reaches the board with or without a prize, the gift only with one" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    ensure_on_card(participant.board_for(@game), @call)
    @call.update!(prize_description: "Sponsored by Bloom Coffee")

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    follow_redirect!

    assert_match "Sponsored by Bloom Coffee", response.body, "a sponsor needs no prize to be credited"
    assert_no_match(/🎁 Sponsored by Bloom Coffee/, response.body)

    @call.update!(prize_call: true)
    get board_path(@publication.public_code)
    assert_match "🎁 Sponsored by Bloom Coffee", response.body, "the gift marks an actual prize"
  end

  test "the newsletter click itself performs the claim and redirects to a clean URL" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    ensure_on_card(participant.board_for(@game), @call)

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")

    assert_redirected_to board_path(@publication.public_code)
    assert_no_match(/reader/, response.headers["Location"])
    assert_no_match(/@/, response.headers["Location"])

    participant = @publication.participants.find_by(email: "reader@example.com")
    assert participant.present?
    assert_equal 1, participant.daily_claims.count
    assert participant.bingo_boards.exists?(game: @game)

    follow_redirect!
    assert_response :success
    assert_select ".receipt-status", text: /Claimed/
    assert_select ".square.claimed", count: 1
    assert_select "button", text: /Claim/, count: 0 # no second claim button anywhere
  end

  test "the board page never contains the raw email" do
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    follow_redirect!
    assert_no_match(/reader@example\.com/, response.body)
  end

  test "repeat clicks are harmless" do
    2.times { get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1") }
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 1, participant.daily_claims.count
  end

  test "two subscribers get different cards dealt from the same pool" do
    get claim_path(@publication.public_code, email: "amy@example.com", issue: "send-1")
    get claim_path(@publication.public_code, email: "ben@example.com", issue: "send-1")

    amy = @publication.participants.find_by(email: "amy@example.com").board_for(@game)
    ben = @publication.participants.find_by(email: "ben@example.com").board_for(@game)
    assert_not_equal amy.bingo_squares.sort_by(&:position).map(&:game_word_id),
      ben.bingo_squares.sort_by(&:position).map(&:game_word_id)

    pool = @game.game_words.pluck(:id)
    [ amy, ben ].each do |board|
      dealt = board.bingo_squares.filter_map(&:game_word_id)
      assert_equal @game.board_cells, dealt.size
      assert_empty dealt - pool
    end
  end

  test "a claim whose word is off the card counts but marks no square" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    board = participant.board_for(@game)
    ensure_off_card(board, @call)

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)
    assert_equal 1, participant.daily_claims.count
    assert_equal 0, board.reload.claimed_word_count

    follow_redirect!
    assert_response :success
    assert_select ".receipt-status.off-card", text: /not on your card/i
    assert_select ".square.claimed", count: 0
  end

  test "a tokenless link opens the board but claims nothing" do
    get claim_path(@publication.public_code, email: "reader@example.com")

    assert_redirected_to board_path(@publication.public_code)
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert participant.present?, "the session is still established for viewing"
    assert_equal 0, participant.daily_claims.count
    assert_equal 0, @game.issues.count

    follow_redirect!
    assert_response :success
    assert_select ".claim-notice", text: /starts with the next newsletter/
  end

  test "yesterday's token opens the board with a notice but claims nothing today" do
    @game.destroy!
    @game = create_running_game(@publication, starts_on: @publication.local_date - 3)
    yesterday = @publication.local_date - 1
    @game.issues.create!(token: "send-old", daily_call: @game.call_for(yesterday), called_on: yesterday)

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-old")

    assert_redirected_to board_path(@publication.public_code)
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 0, participant.daily_claims.count

    follow_redirect!
    assert_select ".claim-notice", text: /earlier email/
  end

  test "a previous game's token never claims in the successor game" do
    @game.issues.create!(token: "send-old-game", daily_call: @call, called_on: @publication.local_date)
    @game.complete
    @publication.rotate_games

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-old-game")

    assert_redirected_to board_path(@publication.public_code)
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 0, participant.daily_claims.count
    assert_equal 0, @publication.active_game.issues.count
  end

  test "an unreplaced campaign merge tag shows a configuration hint and claims nothing" do
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "{{campaign_id}}")

    assert_redirected_to board_path(@publication.public_code)
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 0, participant.daily_claims.count

    follow_redirect!
    assert_select ".claim-notice", text: /fix their bingo link/
  end

  test "missing email lands on the welcome with a friendly notice" do
    get claim_path(@publication.public_code, issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)
    follow_redirect!
    assert_select ".claim-notice"
    assert_select ".unavailable-card"
  end

  test "an unreplaced email merge tag shows a configuration hint" do
    get claim_path(@publication.public_code, email: "{{email}}", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)
    follow_redirect!
    assert_match(/bingo link/, response.body)
  end

  test "malformed email lands on the welcome without claiming" do
    get claim_path(@publication.public_code, email: "not-an-email", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)
    assert_equal 0, @publication.participants.count
  end

  test "unknown publication code 404s without Rails errors" do
    get claim_path("pub_does_not_exist", email: "reader@example.com", issue: "send-1")
    assert_response :not_found
    assert_select ".unavailable-card"
  end

  test "inactive publications do not accept claims" do
    @publication.update!(active: false)
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_response :not_found
  end

  test "a first click with no game yet launches one and claims its first word" do
    @game.destroy!
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)

    game = @publication.active_game
    assert game.present?
    assert_equal 1, game.current_call.position
    assert_equal 1, game.current_call.daily_claims.count
  end

  test "an unpaid publication has no game to claim" do
    @game.destroy!
    @publication.account.update!(stripe_subscription_id: nil, subscription_status: nil,
      subscription_current_period_end: nil)
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)
    follow_redirect!
    assert_match(/no bingo game running/i, response.body)
  end

  test "a completed game rolls into a successor that accepts the claim" do
    @game.complete
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)

    successor = @publication.active_game
    assert successor.present?
    assert_not_equal @game.id, successor.id
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal 1, participant.daily_claims.count
    assert_equal successor.id, participant.daily_claims.sole.game_id
  end

  test "a finished game completes itself and the claim lands on the successor" do
    @game.destroy!
    @game = create_running_game(@publication, starts_on: @publication.local_date - 40, issued: 30)

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    assert_redirected_to board_path(@publication.public_code)

    assert @game.reload.completed?
    successor = @publication.active_game
    participant = @publication.participants.find_by(email: "reader@example.com")
    assert_equal successor.id, participant.daily_claims.sole.game_id
  end

  test "celebration flash fires when the claim completes a bingo line" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    board = participant.board_for(@game)
    ensure_on_card(board, @call)
    todays_square = board.square_for(@call.game_word)
    line = board.lines.detect { |l| l.include?(todays_square.position) && !l.include?(board.center) }
    (line - [ todays_square.position ]).each do |position|
      board.square_at(position).update!(claimed_at: 1.day.ago)
    end

    get claim_path(@publication.public_code, email: "reader@example.com", issue: "send-1")
    follow_redirect!
    assert_select ".celebration", text: /BINGO/
  end
end
