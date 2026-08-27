require "test_helper"

class BoardAccessTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, starts_on: @publication.local_date - 3)
  end

  test "without a participant session the board shows a welcome, not data" do
    get board_path(@publication.public_code)
    assert_response :success
    assert_select ".board-rows", count: 0
    assert_match(/bingo button/, response.body)
    assert_select ".board-lookup input[type=email]"
  end

  test "entering a known email opens the card without claiming anything" do
    participant = Participant.locate_or_register(@publication, "me@example.com")
    force_claim(@game.call_for(@publication.local_date - 1), participant)

    post participant_session_path(@publication.public_code), params: { email: "Me@Example.com " }

    assert_redirected_to board_path(@publication.public_code)
    follow_redirect!
    assert_select ".board-rows"
    assert_equal 1, participant.daily_claims.count, "viewing claims nothing"
  end

  test "entering an unknown email explains that claims create cards, and registers nothing" do
    post participant_session_path(@publication.public_code), params: { email: "stranger@example.com" }

    assert_redirected_to board_path(@publication.public_code)
    assert_equal 0, @publication.participants.count
    follow_redirect!
    assert_select ".board-rows", count: 0
    assert_select ".claim-notice", text: /first time you tap the bingo button/
  end

  test "the participant cookie is signed; a forged token gets nothing" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    participant.board_for(@game)
    cookies["bingo_participant_#{@publication.id}"] = participant.public_token # unsigned
    get board_path(@publication.public_code)
    assert_select ".board-rows", count: 0
  end

  test "a claim session only reveals your own board" do
    other = Participant.locate_or_register(@publication, "other@example.com")
    force_claim(@game.call_for(@publication.local_date - 1), other)

    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    follow_redirect!
    assert_response :success
    me = @publication.participants.find_by(email: "me@example.com")
    assert_no_match other.public_token, response.body
    assert_no_match(/other@example\.com/, response.body)
    assert_no_match me.public_token, response.body, "own token should not leak into markup either"
  end

  test "unclaimed square content stays locked after a missed day" do
    missed_call = @game.call_for(@publication.local_date - 1)
    missed_call.update!(description: "Missed-day secret", link_url: "https://example.com/x", link_text: "Go")

    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    follow_redirect!
    assert_no_match(/Missed-day secret/, response.body)
  end

  test "claimed squares keep their historical content" do
    call = @game.call_for(@publication.local_date - 2)
    call.update!(description: "Vendors and live music", link_url: "https://example.com/market", link_text: "See details")
    participant = Participant.locate_or_register(@publication, "me@example.com")
    force_claim(call, participant)

    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    follow_redirect!
    assert_match(/Vendors and live music/, response.body)
  end

  test "the player page sets privacy headers" do
    get board_path(@publication.public_code)
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
  end

  test "a finished game's board stays visible until the reader joins the new game" do
    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    age_out_game(@game)

    get board_path(@publication.public_code)
    assert_response :success
    assert @game.reload.completed?
    assert @publication.active_game.present?, "rotation launched the successor"
    assert_select ".board-rows"
    assert_match(/GAME COMPLETE/, response.body)
  end
end
