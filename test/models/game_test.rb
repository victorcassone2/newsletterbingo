require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "a game spans exactly 24 local calendar days" do
    game = @publication.games.create!(name: "Span", starts_on: Date.new(2026, 8, 1))
    assert_equal Date.new(2026, 8, 24), game.ends_on
    assert_equal 24, (game.ends_on - game.starts_on).to_i + 1
  end

  test "ends_on stays aligned even if given a wrong value" do
    game = @publication.games.create!(name: "Span", starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 9, 30))
    assert_equal Date.new(2026, 8, 24), game.ends_on
  end

  test "only one open game per publication" do
    create_running_game(@publication)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @publication.games.create!(name: "Second", starts_on: @publication.local_date + 30)
    end
  end

  test "a completed game frees the slot for a new game" do
    game = create_running_game(@publication)
    game.complete
    assert_nothing_raised do
      create_running_game(@publication, starts_on: @publication.local_date + 30)
    end
  end

  test "word selection prefers custom words and yields 24 unique words" do
    selection = Game.random_word_selection(@publication)
    assert_equal 24, selection.size
    assert_equal 24, selection.uniq.size
    assert_includes selection, words(:custom_omaha)
  end

  test "assign_words demands exactly 24 unique words" do
    game = @publication.games.create!(name: "Strict", starts_on: @publication.local_date)
    assert_raises(ArgumentError) { game.assign_words(Word.system.first(23)) }
    assert_raises(ArgumentError) { game.assign_words(Word.system.first(23) + [ Word.system.first ]) }
  end

  test "words are locked after launch" do
    game = create_running_game(@publication)
    assert_raises(Game::NotLaunchable) { game.regenerate_words }
  end

  test "launch creates one call per day using each word exactly once" do
    game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
    assert_equal 24, game.daily_calls.count
    assert_equal (Date.new(2026, 8, 1)..Date.new(2026, 8, 24)).to_a, game.daily_calls.map(&:call_on)
    assert_equal game.game_words.pluck(:id).sort, game.daily_calls.map(&:game_word_id).sort
  end

  test "a launched game cannot launch again" do
    game = create_running_game(@publication)
    assert_raises(Game::NotLaunchable) { game.launch }
  end

  test "no call can exist beyond the 24-day window" do
    game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
    # The (game, game_word) constraint is deferred for swaps, so force it
    # immediate here — transactional tests never reach COMMIT.
    ActiveRecord::Base.connection.execute("SET CONSTRAINTS daily_calls_game_word_unique IMMEDIATE")
    assert_raises(ActiveRecord::RecordNotUnique) do
      # Day 25 would need to reuse one of the 24 words — blocked.
      game.daily_calls.create!(game_word: game.game_words.first, call_on: Date.new(2026, 8, 25))
    end
  end

  test "day_number uses the publication timezone" do
    game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
    travel_to Time.utc(2026, 8, 9, 4, 59) do # Aug 8, 11:59 PM in Chicago
      assert_equal 8, game.day_number
      assert_equal 16, game.days_remaining
    end
    travel_to Time.utc(2026, 8, 9, 5, 1) do # Aug 9, 12:01 AM in Chicago
      assert_equal 9, game.day_number
    end
  end

  test "completing a game preserves its records" do
    game = create_running_game(@publication)
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    game.call_for(@publication.local_date).claim_by(participant)

    game.complete
    assert game.completed?
    assert_equal 24, game.daily_calls.count
    assert_equal 1, game.bingo_boards.count
    assert_equal 1, game.daily_claims.count
  end

  test "claims are refused once the game is completed" do
    game = create_running_game(@publication)
    game.complete
    participant = Participant.locate_or_register(@publication, "reader@example.com")
    assert_raises(DailyCall::NotClaimable) do
      game.call_for(@publication.local_date).claim_by(participant)
    end
  end
end
