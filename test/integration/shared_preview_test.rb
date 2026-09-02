require "test_helper"

class SharedPreviewTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, issued: 0)
  end

  test "anyone with the link sees a sample card and creates nothing" do
    assert_no_difference [ "Participant.count", "BingoBoard.count", "DailyClaim.count", "Issue.count" ] do
      get publication_preview_path(@publication.public_code, @publication.preview_token)
    end

    assert_response :success
    assert_select ".rehearsal h2", text: /A sample card/
    assert_select "section.board-section .square", minimum: 25
    assert_nil @game.reload.current_call
  end

  test "the shared preview offers no way to claim" do
    get publication_preview_path(@publication.public_code, @publication.preview_token)

    assert_select "form[method=post]", count: 0
    assert_match "Tap the bingo button", response.body
  end

  test "a wrong or stale token opens nothing" do
    get publication_preview_path(@publication.public_code, "not-the-token")
    assert_response :not_found

    old_token = @publication.preview_token
    @publication.regenerate_preview_token

    get publication_preview_path(@publication.public_code, old_token)
    assert_response :not_found
  end

  test "one publication's token is useless on another" do
    get publication_preview_path(publications(:lincoln).public_code, @publication.preview_token)
    assert_response :not_found
  end

  test "a publication that is off the air stays off the air" do
    @publication.update!(active: false)
    get publication_preview_path(@publication.public_code, @publication.preview_token)
    assert_response :not_found
  end
end
