require "test_helper"

# Smoke coverage for the consolidated publisher screens: Today in every
# state, the word picker, Library, Setup, and finished-game history.
class AdminScreensTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)
  end

  test "today shows an empty state when there is no game" do
    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "No game yet", response.body
  end

  test "today shows the draft review with tappable word chips" do
    game = @publication.games.create!(name: "Draft Game", starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication))

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Launch game", response.body
    assert_select "a.word-chip", Game::DAYS
  end

  test "today shows the word, next word, schedule, prizes and sponsor once live" do
    game = create_running_game(@publication)
    game.prizes.create!(kind: "line")
    game.update!(sponsor_name: "Midtown Market")

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match game.call_for(@publication.local_date).label, response.body
    assert_match game.next_call.label, response.body
    assert_select "ul.schedule li", Game::DAYS
    assert_match "Line prize", response.body
    assert_match "Brought to you by Midtown Market", response.body
    refute_match "Players", response.body
  end

  test "the word picker lists replacements and swaps one in" do
    game = @publication.games.create!(name: "Draft Game", starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication))
    game_word = game.game_words.first
    replacement = @publication.eligible_words.where.not(id: game.game_words.select(:word_id)).first

    get edit_account_publication_game_game_word_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: game_word.id)
    assert_response :success
    assert_match replacement.label, response.body

    patch account_publication_game_game_word_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: game_word.id),
      params: { word_id: replacement.id }
    assert_redirected_to account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_equal replacement.label, game_word.reload.label
  end

  test "an open game's page redirects to today; a finished game keeps its history page" do
    game = create_running_game(@publication)
    get account_publication_game_path(account_id: @account_id, publication_id: @publication.id, id: game.id)
    assert_redirected_to account_publication_today_path(account_id: @account_id, publication_id: @publication.id)

    game.update_columns(status: "completed")
    get account_publication_game_path(account_id: @account_id, publication_id: @publication.id, id: game.id)
    assert_response :success
    assert_match "Completed", response.body
  end

  test "games index explains why a new game can't start yet" do
    create_running_game(@publication)
    get account_publication_games_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "finish", response.body
    assert_select "a", { text: "New game", count: 0 }
  end

  test "library tabs cover words and sponsors" do
    get account_publication_words_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Library", response.body

    get account_publication_sponsors_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Library", response.body
  end

  test "setup gathers merge tag, embed, branding and settings on one page" do
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)
    assert_response :success
    assert_match "Connect your newsletter", response.body
    assert_match "Branding", response.body
    assert_match @publication.public_code, response.body
    assert_select ".preview-grid .preview-square", 25
  end
end
