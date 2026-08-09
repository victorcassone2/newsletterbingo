require "test_helper"

class AdminFlowTest < ActionDispatch::IntegrationTest
  test "registration creates a user, an account, and an owner membership" do
    post registration_path, params: {
      account_name: "New Media Co.",
      user: { email_address: "founder@example.com", password: "s3curepassword", password_confirmation: "s3curepassword" }
    }
    assert_redirected_to root_path
    user = User.find_by(email_address: "founder@example.com")
    assert user.present?
    account = user.accounts.first
    assert_equal "New Media Co.", account.name
    assert user.memberships.first.owner?
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

    # Create a draft game — it gets 24 words automatically
    post account_publication_games_path(account_id: account_id, publication_id: publication.id), params: {
      game: { name: "Fall Bingo", starts_on: publication.local_date }
    }
    game = publication.games.first
    assert_equal 24, game.game_words.count
    assert game.draft?
    assert_equal 2, game.prizes.count

    # Shuffle words while drafting
    old_words = game.game_words.pluck(:word_id).sort
    post account_publication_game_word_shuffle_path(account_id: account_id, publication_id: publication.id, game_id: game.id)
    assert_equal 24, game.game_words.reload.count

    # Launch — issue cadence (the default): calls exist but stay undated
    post account_publication_game_launch_path(account_id: account_id, publication_id: publication.id, game_id: game.id)
    assert game.reload.active?
    assert_equal 24, game.daily_calls.count
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

    # Configure the current call: description, link, prize call, sponsor
    sponsor = publication.sponsors.create!(name: "Local Bakery")
    patch account_publication_game_call_path(account_id: account_id, publication_id: publication.id,
      game_id: game.id, id: current_call.id), params: {
        daily_call: { description: "Fresh rolls at dawn.", link_url: "https://example.com/bakery",
                      link_text: "See the menu", prize_call: "1", sponsor_id: sponsor.id }
      }
    assert_redirected_to account_publication_today_path(account_id: account_id, publication_id: publication.id)
    current_call.reload
    assert current_call.prize_call?
    assert_equal sponsor, current_call.sponsor

    # Change an unissued word (issued words are locked)
    upcoming_call = game.daily_calls.find_by(call_on: nil)
    replacement = publication.eligible_words.where.not(id: game.game_words.select(:word_id)).first
    patch account_publication_game_call_word_path(account_id: account_id, publication_id: publication.id,
      game_id: game.id, call_id: upcoming_call.id), params: { word_id: replacement.id }
    assert_equal replacement.label, upcoming_call.reload.label

    # Setup page carries the merge tag and the code
    get edit_account_publication_path(account_id: account_id, id: publication.id)
    assert_response :success
    assert_match publication.public_code, response.body
    assert_match(/EMAIL/, response.body)

    # Prize configuration
    prize = game.line_prize
    patch account_publication_game_prize_path(account_id: account_id, publication_id: publication.id,
      game_id: game.id, id: prize.id), params: {
        prize: { enabled: "1", name: "$25 Gift Card", sponsor_id: sponsor.id }
      }
    assert prize.reload.enabled?
    assert_equal sponsor, prize.sponsor

    # Analytics renders
    get account_publication_analytics_path(account_id: account_id, publication_id: publication.id)
    assert_response :success
  end

  test "a finished game can be followed by a new one, and old boards survive" do
    sign_in_as users(:one)
    publication = publications(:omaha)
    old_game = create_running_game(publication)
    participant = Participant.locate_or_register(publication, "loyal@example.com")
    old_game.call_for(publication.local_date).claim_by(participant)
    old_board_id = participant.board_for(old_game).id
    old_layout = participant.board_for(old_game).bingo_squares.sort_by(&:position).map(&:game_word_id)

    old_game.update_columns(starts_on: publication.local_date - 40, ends_on: publication.local_date - 17)

    get new_account_publication_game_path(account_id: accounts(:publisher).id, publication_id: publication.id)
    assert_response :success
    assert old_game.reload.completed?, "visiting the new-game page completes finished games"

    post account_publication_games_path(account_id: accounts(:publisher).id, publication_id: publication.id),
      params: { game: { name: "Next Round", starts_on: publication.local_date } }
    new_game = publication.games.order(:created_at).last
    post account_publication_game_launch_path(account_id: accounts(:publisher).id,
      publication_id: publication.id, game_id: new_game.id)

    new_game.reload.call_for(publication.local_date).claim_by(participant)
    new_board = participant.board_for(new_game)
    assert_not_equal old_board_id, new_board.id

    old_board = participant.bingo_boards.find(old_board_id)
    assert_equal old_layout, old_board.bingo_squares.sort_by(&:position).map(&:game_word_id)
  end
end
