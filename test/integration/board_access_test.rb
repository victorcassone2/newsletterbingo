require "test_helper"

class BoardAccessTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, starts_on: @publication.local_date - 3)
  end

  test "without a participant session the board shows a welcome, not data" do
    get board_path(@publication.public_code)
    assert_response :success
    assert_select ".bingo-grid", count: 0
    assert_match(/Open today/, response.body)
  end

  test "the participant cookie is signed; a forged token gets nothing" do
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    participant.board_for(@game)
    cookies["bingo_participant_#{@publication.id}"] = participant.public_token # unsigned
    get board_path(@publication.public_code)
    assert_select ".bingo-grid", count: 0
  end

  test "a claim session only reveals your own board" do
    other = Participant.locate_or_register(@publication, "other@example.com")
    force_claim(@game.call_for(@publication.local_date - 1), other)

    get claim_path(@publication.public_code, email: "me@example.com")
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

    get claim_path(@publication.public_code, email: "me@example.com")
    follow_redirect!
    assert_no_match(/Missed-day secret/, response.body)
  end

  test "claimed squares keep their historical content" do
    call = @game.call_for(@publication.local_date - 2)
    call.update!(description: "Vendors and live music", link_url: "https://example.com/market", link_text: "See details")
    participant = Participant.locate_or_register(@publication, "me@example.com")
    force_claim(call, participant)

    get claim_path(@publication.public_code, email: "me@example.com")
    follow_redirect!
    assert_match(/Vendors and live music/, response.body)
  end

  test "the player page sets privacy headers" do
    get board_path(@publication.public_code)
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_match(/noindex/, response.headers["X-Robots-Tag"])
  end
end
