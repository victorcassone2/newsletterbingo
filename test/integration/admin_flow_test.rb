require "test_helper"

class AdminFlowTest < ActionDispatch::IntegrationTest
  test "registration creates a user, an account, and an owner membership" do
    post registration_path, params: {
      account_name: "New Media Co.",
      user: { email_address: "founder@example.com", password: "S3cure!password", password_confirmation: "S3cure!password" }
    }
    assert_redirected_to dashboard_path
    user = User.find_by(email_address: "founder@example.com")
    assert user.present?
    account = user.accounts.first
    assert_equal "New Media Co.", account.name
    assert user.memberships.first.owner?

    # The dashboard passes them into their new account with the welcome intact
    follow_redirect!
    assert_redirected_to account_publications_path(account_id: account.id)
    follow_redirect!
    assert_match "Create your first publication", response.body
  end

  test "the full publisher journey: publication, game, launch, daily adjustments, embed" do
    sign_in_as users(:one)
    account_id = accounts(:publisher).id

    # Create a publication
    post account_publications_path(account_id: account_id), params: {
      publication: { name: "Bellevue Beacon", timezone: "America/Chicago",
                     email_merge_tag: "*|EMAIL|*" }
    }
    publication = accounts(:publisher).publications.find_by(name: "Bellevue Beacon")
    assert publication.present?
    assert_match(/\Apub_/, publication.public_code)

    # The account's subscription (from fixtures) covers the new publication,
    # so creation lands straight on Setup; billing has its own tests.
    assert_redirected_to edit_account_publication_path(account_id: account_id, id: publication.id)

    # Visiting Today drafts the first game automatically: 30 words, prizes
    get account_publication_today_path(account_id: account_id, publication_id: publication.id)
    assert_response :success
    assert_match "Your first game", response.body
    game = publication.games.first
    assert_equal 30, game.game_words.count
    assert game.draft?
    assert_equal 2, publication.prizes.count

    # Launch with issue cadence (the default): calls exist but stay undated
    post account_publication_game_launch_path(account_id: account_id, publication_id: publication.id, game_id: game.id)
    assert game.reload.active?
    assert_equal 30, game.daily_calls.count
    assert_equal 0, game.issued_calls.count

    # Today dashboard waits for the first send
    get account_publication_today_path(account_id: account_id, publication_id: publication.id)
    assert_response :success
    assert_match "first word arrives", response.body

    # The first click of a send advances the game and claims the square
    get claim_path(publication.public_code, email: "reader@example.com", issue: "campaign-001")
    assert_redirected_to board_path(publication.public_code)
    current_call = game.reload.current_call
    assert_equal 1, current_call.position
    assert_equal 1, current_call.daily_claims.count

    # Today dashboard now shows the issued word
    get account_publication_today_path(account_id: account_id, publication_id: publication.id)
    assert_response :success
    assert_match current_call.label, response.body

    # Configure the current call: description, link, prize call
    patch account_publication_game_call_path(account_id: account_id, publication_id: publication.id,
      game_id: game.id, id: current_call.id), params: {
        daily_call: { description: "Fresh rolls at dawn.", link_url: "https://example.com/bakery",
                      link_text: "See the menu", prize_call: "1" }
      }
    assert_redirected_to edit_account_publication_game_call_path(account_id: account_id,
      publication_id: publication.id, game_id: game.id, id: current_call.id)
    current_call.reload
    assert current_call.prize_call?

    # Change an unissued word (issued words are locked)
    upcoming_call = game.daily_calls.find_by(call_on: nil)
    replacement = publication.eligible_words.where.not(id: game.game_words.select(:word_id)).first
    patch account_publication_game_call_word_path(account_id: account_id, publication_id: publication.id,
      game_id: game.id, call_id: upcoming_call.id), params: { label: replacement.label.downcase }
    assert_equal replacement.label, upcoming_call.reload.label

    # Setup page carries the merge tag and the code
    get edit_account_publication_path(account_id: account_id, id: publication.id)
    assert_response :success
    assert_match publication.public_code, response.body
    assert_match(/EMAIL/, response.body)

    # Standing sponsor and prize configuration on their own page
    patch account_publication_sponsor_path(account_id: account_id, publication_id: publication.id),
      params: { publication: { sponsor_name: "Local Bakery" } }
    assert_equal "Local Bakery", publication.reload.sponsor_name

    prize = publication.line_prize
    patch account_publication_prize_path(account_id: account_id, publication_id: publication.id,
      id: prize.id), params: {
        prize: { enabled: "1", name: "$25 Gift Card" }
      }
    assert prize.reload.enabled?

    # Analytics renders
    get account_publication_analytics_path(account_id: account_id, publication_id: publication.id)
    assert_response :success
  end

  test "a finished game rolls into the next one automatically, and old boards survive" do
    sign_in_as users(:one)
    publication = publications(:omaha)
    old_game = create_running_game(publication)
    participant = Participant.locate_or_register(publication, "loyal@example.com")
    old_game.call_for(publication.local_date).claim_by(participant)
    old_board_id = participant.board_for(old_game).id
    old_layout = participant.board_for(old_game).bingo_squares.sort_by(&:position).map(&:game_word_id)

    old_game.update_columns(starts_on: publication.local_date - 40, ends_on: publication.local_date - 17)

    get account_publication_today_path(account_id: accounts(:publisher).id, publication_id: publication.id)
    assert_response :success
    assert old_game.reload.completed?, "visiting Today completes finished games"

    new_game = publication.active_game
    assert new_game.present?, "rotation launches the successor automatically"
    assert_not_equal old_game.id, new_game.id
    assert publication.on_deck_game.present?, "a fresh draft goes on deck"

    new_game.call_for(publication.local_date).claim_by(participant)
    new_board = participant.board_for(new_game)
    assert_not_equal old_board_id, new_board.id

    old_board = participant.bingo_boards.find(old_board_id)
    assert_equal old_layout, old_board.bingo_squares.sort_by(&:position).map(&:game_word_id)
  end
end
