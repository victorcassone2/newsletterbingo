require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "a classic game spans one local calendar day per pool word" do
    game = @publication.games.create!(starts_on: Date.new(2026, 8, 1))
    assert_equal 5, game.board_size
    assert_equal 30, game.pool_size
    assert_equal Date.new(2026, 8, 30), game.ends_on
    assert_equal game.pool_size, (game.ends_on - game.starts_on).to_i + 1
  end

  test "a new draft snapshots the publication's format" do
    @publication.update!(board_size: 3)
    game = @publication.games.create!(starts_on: Date.new(2026, 8, 1))
    assert_equal 3, game.board_size
    assert_equal 12, game.pool_size
    assert_equal Date.new(2026, 8, 12), game.ends_on
  end

  test "ends_on stays aligned even if given a wrong value" do
    game = @publication.games.create!(starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 9, 30))
    assert_equal Date.new(2026, 8, 30), game.ends_on
  end

  test "only one active game per publication" do
    create_running_game(@publication)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @publication.games.create!(starts_on: @publication.local_date + 40,
        ends_on: @publication.local_date + 69, status: "active")
    end
  end

  test "only one draft game per publication" do
    @publication.games.create!(starts_on: @publication.local_date)
    assert_raises(ActiveRecord::RecordNotUnique) do
      @publication.games.create!(starts_on: @publication.local_date + 40)
    end
  end

  test "a draft coexists with an active game" do
    create_running_game(@publication)
    assert_nothing_raised do
      @publication.games.create!(starts_on: @publication.local_date + 40)
    end
  end

  test "a completed game frees the slot for a new game" do
    game = create_running_game(@publication)
    game.complete
    assert_nothing_raised do
      create_running_game(@publication, starts_on: @publication.local_date + 40)
    end
  end

  test "word selection prefers custom words and yields the requested count" do
    selection = Game.random_word_selection(@publication, count: 30)
    assert_equal 30, selection.size
    assert_equal 30, selection.uniq.size
    assert_includes selection, words(:custom_omaha)
  end

  test "word selection biases against avoided words when the pool is big enough" do
    avoided = Word.system.active.order(:label).first(10).map(&:id)
    10.times do
      selection = Game.random_word_selection(@publication, count: 30, avoiding: avoided)
      assert_equal 30, selection.size
      assert_empty selection.map(&:id) & avoided
    end
  end

  test "word selection falls back to avoided words when the pool runs short" do
    avoided = @publication.eligible_words.pluck(:id)
    selection = Game.random_word_selection(@publication, count: 30, avoiding: avoided)
    assert_equal 30, selection.size
    assert_equal 30, selection.uniq.size
  end

  test "assign_words demands exactly pool_size unique words" do
    game = @publication.games.create!(starts_on: @publication.local_date)
    assert_raises(ArgumentError) { game.assign_words(Word.system.first(29)) }
    assert_raises(ArgumentError) { game.assign_words(Word.system.first(29) + [ Word.system.first ]) }
  end

  test "words are locked after launch" do
    game = create_running_game(@publication)
    assert_raises(Game::NotLaunchable) { game.regenerate_words }
  end

  test "launch creates one call per day using each word exactly once" do
    travel_to local_noon(@publication, Date.new(2026, 8, 1)) do
      game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
      assert_equal 30, game.daily_calls.count
      assert_equal (Date.new(2026, 8, 1)..Date.new(2026, 8, 30)).to_a, game.daily_calls.map(&:call_on)
      assert_equal game.game_words.pluck(:id).sort, game.daily_calls.map(&:game_word_id).sort
    end
  end

  test "a draft's calls exist undated so content can be written before launch" do
    game = @publication.games.create!(starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication, count: game.pool_size))

    assert_equal 30, game.daily_calls.count
    assert_equal 0, game.issued_calls.count
    assert_equal game.game_words.pluck(:id), game.daily_calls.map(&:game_word_id)
  end

  test "launch follows the draft's reveal order" do
    game = @publication.games.create!(starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication, count: game.pool_size))
    game.daily_calls.find_by(position: 1).move_word_to(30)
    ordered_ids = game.daily_calls.reload.map(&:game_word_id)

    game.launch
    assert_equal ordered_ids, game.daily_calls.reload.map(&:game_word_id)
  end

  test "a draft word drags to a new slot and the others shift" do
    game = @publication.games.create!(starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication, count: game.pool_size))
    labels = game.daily_calls.map(&:label)

    game.daily_calls.find_by(position: 5).move_word_to(2)
    expected = labels[0..0] + [ labels[4] ] + labels[1..3] + labels[5..]
    assert_equal expected, game.daily_calls.reload.map(&:label)
  end

  test "call content written on a draft survives launch" do
    game = @publication.games.create!(starts_on: @publication.local_date)
    game.assign_words(Game.random_word_selection(@publication, count: game.pool_size))
    call = game.daily_calls.find_by(position: 3)
    call.update!(description: "Market day", prize_call: true, prize_description: "Free coffee")

    game.launch
    call.reload
    assert_equal "Market day", call.description
    assert call.prize_call?
    assert_equal 3, call.position
  end

  test "an upcoming word drags to a new slot without touching called words" do
    game = create_running_game(@publication, starts_on: @publication.local_date - 3) # today is Day 4
    labels = game.daily_calls.map(&:label)

    game.daily_calls.find_by(position: 10).move_word_to(5)
    expected = labels[0..3] + [ labels[9] ] + labels[4..8] + labels[10..]
    assert_equal expected, game.daily_calls.reload.map(&:label)
  end

  test "a called word cannot be dragged" do
    game = create_running_game(@publication, starts_on: @publication.local_date - 3)
    assert_raises(DailyCall::WordLocked) { game.daily_calls.find_by(position: 2).move_word_to(10) }
    assert_raises(DailyCall::WordLocked) { game.daily_calls.find_by(position: 10).move_word_to(2) }
  end

  test "a launched game cannot launch again" do
    game = create_running_game(@publication)
    assert_raises(Game::NotLaunchable) { game.launch }
  end

  test "no call can exist beyond the game's window" do
    game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
    # The (game, game_word) constraint is deferred for swaps, so force it
    # immediate here; transactional tests never reach COMMIT.
    ActiveRecord::Base.connection.execute("SET CONSTRAINTS daily_calls_game_word_unique IMMEDIATE")
    assert_raises(ActiveRecord::RecordNotUnique) do
      # Day 31 would need to reuse one of the 30 words, so it's blocked.
      game.daily_calls.create!(game_word: game.game_words.first, call_on: Date.new(2026, 8, 31), position: 31)
    end
  end

  test "day_number uses the publication timezone" do
    game = create_running_game(@publication, starts_on: Date.new(2026, 8, 1))
    travel_to Time.utc(2026, 8, 9, 4, 59) do # Aug 8, 11:59 PM in Chicago
      assert_equal 8, game.day_number
      assert_equal 22, game.days_remaining
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
    assert_equal 30, game.daily_calls.count
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
