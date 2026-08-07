require "test_helper"

# Real threads against the real database: these prove the unique indexes
# and create_or_find_by retries collapse races into single rows.
class ConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication)
    @call = @game.call_for(@publication.local_date)
  end

  teardown do
    @publication.games.destroy_all
    @publication.participants.destroy_all
  end

  test "simultaneous first clicks: one participant, one board, one claim" do
    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          participant = Participant.locate_or_register(@publication, "racer@example.com")
          @call.claim_by(participant)
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, @publication.participants.where(email: "racer@example.com").count
    participant = @publication.participants.find_by(email: "racer@example.com")
    assert_equal 1, participant.bingo_boards.count
    assert_equal 25, participant.bingo_boards.first.bingo_squares.count
    assert_equal 1, participant.daily_claims.count
  end

  test "simultaneous award attempts produce a single prize award" do
    prize = @game.prizes.create!(kind: "line", enabled: true, name: "Card")
    participant = Participant.locate_or_register(@publication, "winner@example.com")

    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection { prize.award_to(participant) }
      end
    end
    threads.each(&:join)

    assert_equal 1, participant.prize_awards.count
  end
end
