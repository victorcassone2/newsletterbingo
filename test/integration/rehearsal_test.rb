require "test_helper"

class RehearsalTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    # Nothing has gone out yet: a reader's click here is the send that
    # draws word 1, which is exactly what a test send must not do.
    @game = create_running_game(@publication, issued: 0)
    @tester = "seed@example.com"
    @publication.test_addresses.create!(email: @tester)
  end

  test "a listed address claims nothing and leaves the game where it was" do
    assert_no_difference [ "Participant.count", "BingoBoard.count", "DailyClaim.count", "Issue.count" ] do
      get claim_path(@publication.public_code, email: @tester, issue: "send-1")
    end

    assert_redirected_to rehearsal_path(@publication.public_code)
    assert_nil @game.reload.current_call, "a test send must not issue a word"
  end

  test "the preview shows the word the next real send will carry" do
    get claim_path(@publication.public_code, email: @tester, issue: "send-1")
    follow_redirect!

    assert_response :success
    assert_select ".rehearsal h2", text: /Nothing was claimed/
    assert_match "test list", response.body
    assert_match @game.daily_calls.first.label, response.body
    assert_select "section.board-section .square", minimum: 25
  end

  test "testing repeatedly is free" do
    5.times { |i| get claim_path(@publication.public_code, email: @tester, issue: "send-#{i}") }

    assert_equal 0, Issue.count
    assert_nil @game.reload.current_call
    assert_equal 0, @publication.participants.count
  end

  test "a sub-addressed seed previews on the same listing" do
    get claim_path(@publication.public_code, email: "seed+mailchimp@example.com", issue: "send-1")

    assert_redirected_to rehearsal_path(@publication.public_code)
    assert_nil @game.reload.current_call
  end

  test "the same token still draws word 1 for the real send afterwards" do
    get claim_path(@publication.public_code, email: @tester, issue: "campaign-abc")
    get claim_path(@publication.public_code, email: "reader@example.com", issue: "campaign-abc")

    assert_equal @game.daily_calls.first, @game.reload.current_call
    assert_equal 1, @publication.participants.count
  end

  test "an unlisted address claims for real, account member or not" do
    [ "reader@example.com", users(:one).email_address ].each_with_index do |email, index|
      travel index * (Game::ISSUE_INTERVAL_FLOOR + 1.hour) do
        get claim_path(@publication.public_code, email: email, issue: "send-#{index}")
        assert_redirected_to board_path(@publication.public_code)
      end
    end

    assert_equal 2, @publication.participants.count
    assert_equal 2, @game.reload.issued_calls.count
  end

  test "unlisting an address puts it back in the game" do
    @publication.test_addresses.find_by(email: @tester).destroy

    get claim_path(@publication.public_code, email: @tester, issue: "send-1")

    assert_redirected_to board_path(@publication.public_code)
    assert_equal @game.daily_calls.first, @game.reload.current_call
  end

  test "the preview never puts the address in the URL" do
    get claim_path(@publication.public_code, email: @tester, issue: "send-1")
    assert_no_match(/@/, response.headers["Location"])

    follow_redirect!
    assert_no_match(/#{Regexp.escape(@tester)}/, response.body)
  end

  test "the preview offers no way to claim" do
    get claim_path(@publication.public_code, email: @tester, issue: "send-1")
    follow_redirect!

    assert_select "form[method=post]", count: 0
  end

  test "an unreplaced merge tag reads as a test send, not a broken newsletter" do
    get claim_path(@publication.public_code, email: "*|EMAIL|*", issue: "send-1")
    follow_redirect!

    assert_match "expected in most test sends", response.body
    assert_nil @game.reload.current_call
  end
end
