require "test_helper"

class RotateGamesJobTest < ActiveJob::TestCase
  test "rotates active publications and skips inactive ones" do
    active_publication = publications(:omaha)
    inactive_publication = publications(:lincoln)
    inactive_publication.update!(active: false)

    RotateGamesJob.perform_now

    assert active_publication.on_deck_game.present?
    assert_nil inactive_publication.on_deck_game
  end
end
