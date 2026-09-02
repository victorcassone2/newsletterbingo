require "test_helper"

# Smoke coverage for the consolidated publisher screens: Today in every
# state, the word picker, Library, Setup, and finished-game history.
class AdminScreensTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @account_id = accounts(:publisher).id
    @publication = publications(:omaha)
  end

  test "today launches the first game automatically and waits for the first send" do
    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "first word arrives", response.body
    assert_match "Word 1 of 30", response.body
    assert_no_match(/Launch game/, response.body)
    assert_select "ul.schedule li", @publication.pool_size

    game = @publication.active_game
    assert game.present?
    assert_equal 30, game.game_words.count
    assert_equal 0, game.issued_calls.count
  end

  test "today shows the word, next word, schedule and the on-deck game once live" do
    game = create_running_game(@publication)

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match game.current_call.label, response.body
    assert_match game.next_call.label, response.body
    assert_select "ul.schedule li", game.pool_size
    assert_select ".tabs a", text: "Next game"
    assert_select ".pulse .pulse-num", text: "0" # the claims pulse, before any claims
    assert_select ".ondeck", text: /On deck/

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id, tab: "next")
    assert_response :success
    assert_match "Next game", response.body
    assert_match "What carries over", response.body
    assert_select "ul.schedule li", game.pool_size # the on-deck game's editable reveal order
    assert_select "ul.schedule li[draggable=true]", game.pool_size
  end

  test "the claims card says what it is waiting for until a second word can draw a line" do
    create_running_game(@publication)
    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_select ".pulse-fill .pulse-wait", text: /starts with your second word/
    assert_select ".pulse-fill .pulse-row svg", 0
  end

  test "the claims card counts players until there are enough of them for a rate" do
    game = create_running_game(@publication)
    seat_players(game, 1)

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_select ".pulse-sub", text: /1 player so far this game/
    assert_no_match(/100% of 1/, response.body)

    seat_players(game, Publication::Analytics::RATE_FLOOR)

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_select ".pulse-sub", text: /% of \d+ players this game/
  end

  test "the claims card draws its line once a second word has been called" do
    create_running_game(@publication, starts_on: @publication.local_date - 3)
    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_select ".pulse-fill .pulse-row svg", 1
    assert_select ".pulse-fill .pulse-wait", 0
  end

  test "the schedule collapses all but the last two previous words" do
    create_running_game(@publication, starts_on: @publication.local_date - 10) # word 11 is current

    get account_publication_today_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_select "ul.schedule li", @publication.pool_size + 1 # 30 words plus the reveal trigger
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
    assert_match "Extra call content", response.body
    assert_match replacement.label, response.body

    patch account_publication_game_call_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: call.id),
      params: { daily_call: { description: "Market day details." } }
    assert_redirected_to edit_account_publication_game_call_path(account_id: @account_id,
      publication_id: @publication.id, game_id: game.id, id: call.id),
      "saving stays on the call's page"
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

  test "the library lists the word pool with the custom-word goal" do
    get account_publication_words_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Make the game yours", response.body
    assert_select "#word-goal"
    assert_select "#ready-cloud"
  end

  test "quick-adding a word streams the chip and goal, no reload" do
    post account_publication_words_path(account_id: @account_id, publication_id: @publication.id),
      params: { word: { label: "gene leahy" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %(action="prepend" target="ready-cloud"), response.body
    assert_match "GENE LEAHY", response.body
    assert @publication.words.exists?(label: "GENE LEAHY")

    # A duplicate streams the error into place instead of adding a chip
    post account_publication_words_path(account_id: @account_id, publication_id: @publication.id),
      params: { word: { label: "Gene Leahy" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_match %(target="word-errors"), response.body
    assert_match "already in the word library", response.body
    assert_equal 1, @publication.words.where(label: "GENE LEAHY").count
  end

  test "archiving a word swaps its chip in place" do
    word = @publication.words.create!(label: "OLD MARKET")
    post account_publication_word_archival_path(account_id: @account_id, publication_id: @publication.id, word_id: word.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match %(target="#{ActionView::RecordIdentifier.dom_id(word)}"), response.body
    assert word.reload.archived?
  end

  test "sponsors and prizes are standing setup, edited on their own page" do
    get account_publication_prizes_path(account_id: @account_id, publication_id: @publication.id)
    assert_response :success
    assert_match "Sponsorship", response.body
    assert_match "Line prize", response.body
    assert_match "Blackout prize", response.body
    assert_match "In the email block", response.body # the sponsor footprint
    assert_match "awarded this game", response.body  # award counts on each prize

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

  test "the enable toggle swaps just the prize card, no page reload" do
    prize = @publication.line_prize
    prize.update!(enabled: true, name: "$25 Gift Card")

    patch account_publication_prize_path(account_id: @account_id, publication_id: @publication.id, id: prize.id),
      params: { prize: { enabled: "0" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %(target="#{ActionView::RecordIdentifier.dom_id(prize)}"), response.body
    assert_not prize.reload.enabled?

    # Enabling a prize with no name fails in place, with the error in the card
    prize.update!(name: nil)
    patch account_publication_prize_path(account_id: @account_id, publication_id: @publication.id, id: prize.id),
      params: { prize: { enabled: "1" } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_entity
    assert_match "Name can", response.body
    assert_not prize.reload.enabled?
  end

  test "setup gathers the platform, embed, test check, branding and settings on one page" do
    get edit_account_publication_path(account_id: @account_id, id: @publication.id)
    assert_response :success
    assert_match "Sending from beehiiv", response.body
    assert_match "Branding", response.body
    assert_match @publication.public_code, response.body
    assert_select ".preview-grid .preview-square", 25
    assert_select "details.tag-details input[name=?]", "publication[campaign_merge_tag]",
      message: "the tags are a disclosure now, not the question the page opens with"
    assert_match "Watching for your test click", response.body
    assert_select "input[name=?]", "publication[board_size]", message: "format belongs with the game, in General"
    assert_no_match(/send_days/, response.body)
  end

  private
    # Boards, not claims: the rate's denominator is everyone holding a card.
    def seat_players(game, count)
      count.times do |index|
        Participant.locate_or_register(game.publication, "player#{index}@example.com").board_for(game)
      end
    end
end
