require "test_helper"

class GameSchedulingTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
  end

  test "launch leaves every word queued and undated" do
    game = launch_game

    assert_equal game.pool_size, game.daily_calls.count
    assert_equal 0, game.issued_calls.count
    assert_nil game.current_call
    assert_equal 1, game.next_call.position
  end

  test "a stale on-deck draft launches from today, not its estimated start" do
    game = launch_game(starts_on: @publication.local_date - 10)

    assert_equal @publication.local_date, game.reload.starts_on
    assert_equal @publication.local_date + game.pool_size - 1, game.ends_on
  end

  test "sends_away counts a queued call's place in the unissued queue" do
    game = launch_game
    issued = game.claimable_call_for("send-1")

    assert_nil issued.sends_away
    assert_equal 1, game.daily_calls.find_by(position: 2).sends_away
    assert_equal 2, game.daily_calls.find_by(position: 3).sends_away
  end

  test "a publication with no campaign tag advances on the first click" do
    @publication.update!(campaign_merge_tag: nil)
    game = launch_game

    call = game.claimable_call_for(nil)

    assert_equal 1, call.position
    assert_equal @publication.local_date, call.call_on
    assert_equal 1, game.issues.count
  end

  test "a second tokenless click inside the floor claims the same word" do
    @publication.update!(campaign_merge_tag: nil)
    game = launch_game
    first = game.claimable_call_for(nil)

    second = game.claimable_call_for(nil)

    assert_equal first, second, "everyone in one send claims that send's word"
    assert_equal 1, game.issues.count
  end

  test "a tokenless click after the floor advances to the next word" do
    @publication.update!(campaign_merge_tag: nil)
    game = launch_game
    game.claimable_call_for(nil)

    travel 13.hours do
      assert_equal 2, game.claimable_call_for(nil).position
    end
    assert_equal 2, game.issues.count
  end

  private
    def launch_game(starts_on: @publication.local_date)
      game = @publication.games.create!(starts_on: starts_on)
      game.assign_words(Game.random_word_selection(@publication, count: game.pool_size))
      game.launch
      game
    end
end
