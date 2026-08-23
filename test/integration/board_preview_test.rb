require "test_helper"

class BoardPreviewTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    @game = @publication.games.first
    post account_publication_game_launch_path(account_id: @account_id, publication_id: @publication.id, game_id: @game.id)
  end

  test "publisher previews the reader board without creating any player data" do
    assert_no_difference [ "Participant.count", "BingoBoard.count", "DailyClaim.count" ] do
      get account_publication_board_preview_path(account_id: @account_id, publication_id: @publication.id)
    end
    assert_response :success
    assert_match "YOUR BINGO CARD", response.body
  end

  test "preview shows the state after the next word goes out" do
    get account_publication_board_preview_path(account_id: @account_id, publication_id: @publication.id, word: "next")
    assert_response :success
    assert_match @game.reload.next_call.label, response.body
  end
end
