require "test_helper"

class OutboundClickTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
    @call = @game.call_for(@publication.local_date)
    @call.update!(description: "Market", link_url: "https://example.com/market", link_text: "Details")
  end

  test "a claimed call's link redirects and counts the click" do
    get claim_path(@publication.public_code, email: "me@example.com")
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
    tomorrow = @game.call_for(@publication.local_date + 1)
    tomorrow.update!(link_url: "https://example.com/future", link_text: "Future")
    get claim_path(@publication.public_code, email: "me@example.com")
    get call_outbound_path(@publication.public_code, tomorrow.id)
    assert_redirected_to board_path(@publication.public_code)
    assert_equal 0, tomorrow.reload.link_clicks_count
  end

  test "the destination is never taken from request params" do
    get claim_path(@publication.public_code, email: "me@example.com")
    get call_outbound_path(@publication.public_code, @call.id, redirect: "https://evil.example.com")
    assert_redirected_to "https://example.com/market"
  end

  test "prize links require the matching achievement" do
    prize = @publication.line_prize
    prize.update!(enabled: true, name: "Card",
      link_url: "https://example.com/prize", link_text: "Redeem")
    get claim_path(@publication.public_code, email: "me@example.com")

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
    rival_call = rival_game.call_for(publications(:rival).local_date)
    rival_call.update!(link_url: "https://example.com/rival", link_text: "X")

    get claim_path(@publication.public_code, email: "me@example.com")
    get call_outbound_path(@publication.public_code, rival_call.id)
    assert_response :not_found
  end
end
