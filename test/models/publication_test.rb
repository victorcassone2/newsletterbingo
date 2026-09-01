require "test_helper"

class PublicationTest < ActiveSupport::TestCase
  test "generates a secure public code on create" do
    publication = accounts(:publisher).publications.create!(name: "New Pub")
    assert_match(/\Apub_[1-9A-HJ-NP-Za-km-z]{20}\z/, publication.public_code)
  end

  test "public codes are unique" do
    publication = accounts(:publisher).publications.new(name: "Dup",
      public_code: publications(:omaha).public_code)
    assert_not publication.valid?
    assert publication.errors[:public_code].any?
  end

  test "colors must be hex" do
    publication = publications(:omaha)
    publication.primary_color = "red"
    assert_not publication.valid?
    publication.primary_color = "#AB12CD"
    assert publication.valid?
  end

  test "colors are stored lowercase, however they were typed" do
    publication = publications(:omaha)
    publication.update!(primary_color: " #AB12CD ")
    assert_equal "#ab12cd", publication.reload.primary_color
  end

  test "a new publication starts on the Newsletter Bingo palette" do
    publication = Account.first.publications.new

    assert_equal "#b45309", publication.primary_color
    assert_equal "#f59e0b", publication.accent_color
    assert_equal "#fcfcfc", publication.background_color
    assert_equal "#2a2118", publication.text_color
  end

  test "timezone must be recognized" do
    publication = publications(:omaha)
    publication.timezone = "Mars/Olympus"
    assert_not publication.valid?
    publication.timezone = "America/Denver"
    assert publication.valid?
  end

  test "email merge tag has a sensible default and is required" do
    publication = accounts(:publisher).publications.create!(name: "Y")
    assert_equal "{{email}}", publication.email_merge_tag

    publication.email_merge_tag = ""
    assert_not publication.valid?
  end

  test "local_date follows the publication timezone, not the server" do
    publication = publications(:omaha) # America/Chicago
    travel_to Time.utc(2026, 8, 16, 3, 0) do # 10 PM Aug 15 in Chicago
      assert_equal Date.new(2026, 8, 15), publication.local_date
    end
    travel_to Time.utc(2026, 8, 16, 6, 0) do # 1 AM Aug 16 in Chicago
      assert_equal Date.new(2026, 8, 16), publication.local_date
    end
  end

  test "eligible words include system words and own custom words only" do
    eligible = publications(:omaha).eligible_words
    assert_includes eligible, words(:custom_omaha)
    assert_includes eligible, words(:system_0)
    assert_not_includes eligible, words(:custom_rival)
  end

  test "rotation launches the first game and puts a fresh draft on deck" do
    publication = publications(:omaha)
    publication.rotate_games

    game = publication.active_game
    assert game.present?
    assert_equal 30, game.game_words.count
    assert_equal 0, game.issued_calls.count, "the first word waits for a send"
    assert publication.on_deck_game.present?
  end

  test "rotation launches nothing for a publication the account stopped paying for" do
    publication = publications(:omaha)
    publication.account.update!(stripe_subscription_id: nil, subscription_status: nil,
      subscription_current_period_end: nil)
    publication.rotate_games

    assert_nil publication.active_game
    assert publication.on_deck_game.present?, "drafts keep drafting"
  end

  test "changing the format reshapes the on-deck draft but never a game in progress" do
    publication = publications(:omaha)
    game = create_running_game(publication)
    publication.rotate_games
    draft = publication.on_deck_game
    assert_equal 30, draft.game_words.count

    publication.update!(board_size: 3)

    draft.reload
    assert_equal 3, draft.board_size
    assert_equal 12, draft.pool_size
    assert_equal 12, draft.game_words.count
    game.reload
    assert_equal 5, game.board_size
    assert_equal 30, game.game_words.count
  end

  test "rotation leaves a healthy in-flight game alone" do
    publication = publications(:omaha)
    game = create_running_game(publication)
    publication.rotate_games

    assert game.reload.active?
    assert_equal game, publication.active_game
    assert publication.on_deck_game.present?
  end

  test "rotation is idempotent" do
    publication = publications(:omaha)
    create_running_game(publication)
    2.times { publication.rotate_games }

    assert_equal 1, publication.games.active.count
    assert_equal 1, publication.games.draft.count
  end

  test "an over game rolls straight into its successor, clamped to today" do
    publication = publications(:omaha)
    game = age_out_game(create_running_game(publication))

    publication.rotate_games

    assert game.reload.completed?
    successor = publication.active_game
    assert successor.present?
    assert_not_equal game.id, successor.id
    assert_equal publication.local_date, successor.starts_on
    assert publication.on_deck_game.present?
  end

  test "a pre-staged draft launches the moment the current game runs out" do
    publication = publications(:omaha)
    game = create_running_game(publication)
    on_deck = create_on_deck_draft(publication)

    age_out_game(game)
    publication.rotate_games

    assert game.reload.completed?
    assert on_deck.reload.active?
    assert_equal publication.local_date, on_deck.starts_on
  end

  test "sponsor and prizes stay on across rollover" do
    publication = publications(:omaha)
    publication.update!(sponsor_name: "Dundee Coffee")
    publication.line_prize.update!(enabled: true, name: "$25 Gift Card")
    age_out_game(create_running_game(publication))

    publication.rotate_games

    assert publication.active_game.present?
    assert_equal "Dundee Coffee", publication.reload.sponsor_name
    assert publication.line_prize.enabled?, "the standing prize survives rotation untouched"
  end

  test "a new publication gets its standing prize pair, disabled" do
    publication = accounts(:publisher).publications.create!(name: "New Pub",
      timezone: "America/Chicago", email_merge_tag: "{{email}}")

    assert_equal %w[ blackout line ], publication.prizes.pluck(:kind).sort
    assert publication.prizes.none?(&:enabled?)
    assert_nil publication.sponsor_name
  end

  test "recent_word_ids come from the last completed game" do
    publication = publications(:omaha)
    assert_equal [], publication.recent_word_ids

    game = create_running_game(publication)
    game.complete
    assert_equal game.game_words.pluck(:word_id).sort, publication.recent_word_ids.sort
  end
end
