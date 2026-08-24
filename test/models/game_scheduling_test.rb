require "test_helper"

class GameSchedulingTest < ActiveSupport::TestCase
  test "calendar launch schedules words on the publication's send days only" do
    publication = publications(:omaha)
    publication.update!(cadence: "calendar", send_days: [ 1, 3, 5 ]) # Mon/Wed/Fri
    monday = publication.local_date.next_occurring(:monday)

    game = publication.games.create!(starts_on: monday)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
    game.launch

    dates = game.daily_calls.map(&:call_on)
    assert_equal game.pool_size, dates.size
    assert_equal monday, dates.first
    assert dates.all? { |date| [ 1, 3, 5 ].include?(date.wday) }
    assert_equal dates.sort, dates
    assert_equal dates.last, game.reload.ends_on
    assert_equal (1..game.pool_size).to_a, game.daily_calls.map(&:position)
  end

  test "calendar launch with every send day keeps the consecutive schedule" do
    publication = publications(:omaha)
    game = publication.games.create!(starts_on: publication.local_date)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
    game.launch

    dates = game.daily_calls.map(&:call_on)
    assert_equal (publication.local_date..publication.local_date + 29).to_a, dates
  end

  test "a stale on-deck draft launches from today, not its estimated start" do
    publication = publications(:omaha)
    game = publication.games.create!(starts_on: publication.local_date - 10)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
    game.launch

    assert_equal publication.local_date, game.reload.starts_on
    assert_equal publication.local_date, game.daily_calls.minimum(:call_on)
  end

  test "send days empty falls back to every day" do
    publication = publications(:omaha)
    publication.update!(send_days: [])
    assert_equal (0..6).to_a, publication.sending_wdays
  end

  test "switching a calendar game to issue cadence requeues not-yet-called words" do
    publication = publications(:omaha)
    game = create_running_game(publication, starts_on: publication.local_date - 5)

    publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")

    assert_equal 6, game.issued_calls.count
    assert_equal game.pool_size - 6, game.daily_calls.where(call_on: nil).count
    assert_equal 6, game.current_call.position
    assert game.daily_calls.find_by(position: 7).word_changeable?
  end

  test "switching an issue game to calendar cadence dates the queued words on send days" do
    publication = publications(:omaha)
    publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")
    game = publication.games.create!(starts_on: publication.local_date)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
    game.launch
    first_call = game.call_for_issue("send-1")

    publication.update!(cadence: "calendar", send_days: [])

    assert_equal publication.local_date, first_call.reload.call_on
    assert_equal game.pool_size, game.issued_calls.count
    assert_equal publication.local_date + 1, game.daily_calls.find_by(position: 2).call_on
    assert_equal publication.local_date, game.reload.starts_on
    assert_equal publication.local_date + (game.pool_size - 1), game.ends_on
  end

  test "switching cadence with no active game changes nothing" do
    publication = publications(:omaha)
    game = publication.games.create!(starts_on: publication.local_date)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))

    publication.update!(cadence: "issues", campaign_merge_tag: "{{campaign}}")

    assert game.reload.draft?
    assert_equal 0, game.issued_calls.count
  end
end
