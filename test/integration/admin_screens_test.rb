require "test_helper"

# Smoke coverage for the consolidated publisher screens: Today in every
# state, the word picker, Library, Setup, and finished-game history.
class AdminScreensTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)
  end

  test "today drafts the first game automatically and shows it for review" do
    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Your first game", response.body
    assert_match "Launch game", response.body
    assert_select "ul.schedule li", Game::DAYS

    game = @publication.on_deck_game
    assert game.present?
    assert_equal 24, game.game_words.count
    assert_nil @publication.active_game
  end

  test "today shows the word, next word, schedule and the on-deck game once live" do
    game = create_running_game(@publication)

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match game.call_for(@publication.local_date).label, response.body
    assert_match game.next_call.label, response.body
    assert_select "ul.schedule li", Game::DAYS
    assert_select ".tabs a", text: "Next game"
    assert_select ".pulse .pulse-num", text: "0" # the claims pulse, before any claims
    assert_select ".ondeck", text: /On deck/

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id, tab: "next")
    assert_response :success
    assert_match "Next game", response.body
    assert_match "What carries over", response.body
    assert_select "ul.schedule li", Game::DAYS # the on-deck game's editable reveal order
    assert_select "ul.schedule li[draggable=true]", Game::DAYS
  end

  test "the schedule collapses all but the last two previous words" do
    create_running_game(@publication, starts_on: @publication.local_date - 10) # today is Day 11

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_select "ul.schedule li", Game::DAYS + 1 # 24 words plus the reveal trigger
    assert_select "ul.schedule li[hidden]", 8 # words 1-8 collapsed; 9 and 10 stay visible
    assert_select ".schedule .link-button", text: "View all previous words"
  end

  test "dragging a draft word PATCHes its slot" do
    game = create_on_deck_draft(@publication)
    moved = game.daily_calls.find_by(position: 8)
    moved_word_id = moved.game_word_id

    patch account_publication_game_call_position_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, call_id: moved.id), params: { to: 1 }

    assert_response :no_content
    assert_equal moved_word_id, game.daily_calls.find_by(position: 1).game_word_id
  end

  test "dragging an upcoming word PATCHes its slot; called words refuse" do
    game = create_running_game(@publication, starts_on: @publication.local_date - 3)
    moved = game.daily_calls.find_by(position: 12)
    moved_word_id = moved.game_word_id

    patch account_publication_game_call_position_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, call_id: moved.id), params: { to: 6 }
    assert_response :no_content
    assert_equal moved_word_id, game.daily_calls.find_by(position: 6).game_word_id

    called = game.daily_calls.find_by(position: 2)
    patch account_publication_game_call_position_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, call_id: called.id), params: { to: 10 }
    assert_response :unprocessable_entity
  end

  test "a draft call's page takes content and replaces the word, like a live one" do
    game = create_on_deck_draft(@publication)
    call = game.daily_calls.first
    replacement = @publication.eligible_words.where.not(id: game.game_words.select(:word_id)).first

    get edit_account_publication_game_call_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: call.id)
    assert_response :success
    assert_match "Call content", response.body
    assert_match replacement.label, response.body

    patch account_publication_game_call_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: call.id),
      params: { daily_call: { description: "Market day details." } }
    assert_redirected_to account_publication_today_path(account_id: @account_id, publication_id: @publication.id, tab: "next"),
      "draft edits land back on the next-game tab"
    assert_equal "Market day details.", call.reload.description

    patch account_publication_game_call_word_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, call_id: call.id),
      params: { label: replacement.label.downcase }
    assert_equal replacement.label, call.reload.label
  end

  test "typing an unknown word adds it to the library and swaps it in" do
    game = create_on_deck_draft(@publication)
    call = game.daily_calls.first

    patch account_publication_game_call_word_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, call_id: call.id),
      params: { label: "corn maze" }

    assert_equal "CORN MAZE", call.reload.label
    assert @publication.words.exists?(label: "CORN MAZE"), "the new word joins the publication's library"
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

  test "games index lists history with no manual game creation" do
    create_running_game(@publication)
    get account_publication_games_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "continuously", response.body
    assert_select "a", { text: "New game", count: 0 }
    assert_select "span.badge-green", text: /Live/
    assert_select "span.badge-amber", text: "Draft"
  end

  test "the library lists the word pool" do
    get account_publication_words_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Library", response.body
  end

  test "sponsors and prizes are standing setup, edited on their own page" do
    get account_publication_prizes_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Sponsors &amp; Prizes", response.body
    assert_match "Line prize", response.body
    assert_match "Blackout prize", response.body

    patch account_publication_sponsor_path(account_id: @account_id, publication_id: @publication.id),
      params: { publication: { sponsor_name: "Midtown Market" } }
    assert_redirected_to account_publication_prizes_path(account_id: @account_id, publication_id: @publication.id)
    assert_equal "Midtown Market", @publication.reload.sponsor_name

    prize = @publication.line_prize
    patch account_publication_prize_path(account_id: @account_id, publication_id: @publication.id, id: prize.id),
      params: { prize: { enabled: "1", name: "$25 Gift Card" } }
    assert_redirected_to account_publication_prizes_path(account_id: @account_id, publication_id: @publication.id)
    assert prize.reload.enabled?
    assert_equal "$25 Gift Card", prize.name
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
