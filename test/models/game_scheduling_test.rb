require "test_helper"

class GameSchedulingTest < ActiveSupport::TestCase
  test "calendar launch schedules words on the publication's send days only" do
    publication = publications(:omaha)
    publication.update!(cadence: "calendar", send_days: [ 1, 3, 5 ]) # Mon/Wed/Fri
    monday = publication.local_date.next_occurring(:monday)

    game = publication.games.create!(name: "MWF Game", starts_on: monday)
    game.assign_words(Game.random_word_selection(publication))
    game.launch

    dates = game.daily_calls.map(&:call_on)
    assert_equal Game::DAYS, dates.size
    assert_equal monday, dates.first
    assert dates.all? { |date| [ 1, 3, 5 ].include?(date.wday) }
    assert_equal dates.sort, dates
    assert_equal dates.last, game.reload.ends_on
    assert_equal (1..Game::DAYS).to_a, game.daily_calls.map(&:position)
  end

  test "calendar launch with every send day keeps the consecutive schedule" do
    publication = publications(:omaha)
    game = publication.games.create!(name: "Daily Game", starts_on: publication.local_date)
    game.assign_words(Game.random_word_selection(publication))
    game.launch

    dates = game.daily_calls.map(&:call_on)
    assert_equal (publication.local_date..publication.local_date + 23).to_a, dates
  end

  test "send days empty falls back to every day" do
    publication = publications(:omaha)
    publication.update!(send_days: [])
    assert_equal (0..6).to_a, publication.sending_wdays
  end
end
