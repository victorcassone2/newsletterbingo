require "test_helper"

class OutboundClickTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    # Nothing has gone out yet: the claim below is the send that draws it.
    @game = create_running_game(@publication, issued: 0)
    @call = @game.daily_calls.first
    @call.update!(description: "Market", link_url: "https://example.com/market", link_text: "Details")
  end

  test "a claimed call's link redirects and counts the click" do
    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    assert_difference -> { @call.reload.link_clicks_count } do
      get call_outbound_path(@publication.public_code, @call.id)
    end
    assert_redirected_to "https://example.com/market"
  end

  test "no session means no external redirect" do
    get call_outbound_path(@publication.public_code, @call.id)
    assert_redirected_to board_path(@publication.public_code)
  end

  test "an unclaimed call's link stays locked" do
    queued = @game.daily_calls.second
    queued.update!(link_url: "https://example.com/future", link_text: "Future")
    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    get call_outbound_path(@publication.public_code, queued.id)
    assert_redirected_to board_path(@publication.public_code)
    assert_equal 0, queued.reload.link_clicks_count
  end

  test "the destination is never taken from request params" do
    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    get call_outbound_path(@publication.public_code, @call.id, redirect: "https://evil.example.com")
    assert_redirected_to "https://example.com/market"
  end

  test "prize links require the matching achievement" do
    prize = @publication.line_prize
    prize.update!(enabled: true, name: "Card",
      link_url: "https://example.com/prize", link_text: "Redeem")
    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")

    get prize_outbound_path(@publication.public_code, prize.id)
    assert_redirected_to board_path(@publication.public_code), "no bingo yet, no prize link"

    board = @publication.participants.find_by(email: "me@example.com").board_for(@game)
    (0..4).each { |position| board.square_at(position).update!(claimed_at: Time.current) }
    board.refresh_achievements

    get prize_outbound_path(@publication.public_code, prize.id)
    assert_redirected_to "https://example.com/prize"
  end

  test "another publication's call is not reachable" do
    rival_game = create_running_game(publications(:rival))
    rival_call = rival_game.current_call
    rival_call.update!(link_url: "https://example.com/rival", link_text: "X")

    get claim_path(@publication.public_code, email: "me@example.com", issue: "send-1")
    get call_outbound_path(@publication.public_code, rival_call.id)
    assert_response :not_found
  end
end
