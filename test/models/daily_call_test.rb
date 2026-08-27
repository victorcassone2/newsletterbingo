require "test_helper"

class DailyCallTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, starts_on: @publication.local_date - 5)
    @participant = Participant.locate_or_register(@publication, "reader@example.com")
    @today = @game.current_call
  end

  test "claiming today creates one claim and marks exactly one square" do
    board = @participant.board_for(@game)
    ensure_on_card(board, @today)
    @today.claim_by(@participant)
    claimed = board.reload.bingo_squares.reject(&:free?).select { |s| s.claimed_at.present? }
    assert_equal 1, claimed.size
    assert_equal @today.game_word_id, claimed.first.game_word_id
  end

  test "repeat clicks are idempotent" do
    first = @today.claim_by(@participant)
    second = @today.claim_by(@participant)
    assert_equal first.id, second.id
    assert_equal 1, @participant.daily_claims.count
  end

  test "yesterday cannot be claimed" do
    yesterday = @game.call_for(@publication.local_date - 1)
    assert_raises(DailyCall::NotClaimable) { yesterday.claim_by(@participant) }
    assert_equal 0, @participant.daily_claims.count
  end

  test "a word still in the queue cannot be claimed" do
    assert_raises(DailyCall::NotClaimable) { @game.next_call.claim_by(@participant) }
  end

  test "a missed day stays blank forever" do
    missed = @game.call_for(@publication.local_date - 2)
    @today.claim_by(@participant)
    board = @participant.board_for(@game)
    ensure_on_card(board, missed)
    missed_square = board.square_for(missed.game_word)
    assert_nil missed_square.claimed_at
    assert_raises(DailyCall::NotClaimable) { missed.claim_by(@participant) }
  end

  test "the current word stays claimable until the next send, not until midnight" do
    chicago = @publication.tz
    tonight = chicago.local(@publication.local_date.year, @publication.local_date.month,
      @publication.local_date.day, 23, 55)

    travel_to tonight do
      assert @today.claimable_now?
    end
    travel_to tonight + 10.minutes do
      assert @today.claimable_now?, "nothing has gone out since, so the word is still the current one"
    end
  end

  test "a word that has gone out is part of game history and can't change" do
    assert_not @today.word_changeable?
    unused = Word.system.where.not(id: @game.game_words.select(:word_id)).first
    assert_raises(DailyCall::WordLocked) { @today.replace_word(unused) }
  end

  test "replacing a queued word updates every board in place" do
    board = @participant.board_for(@game)
    queued = @game.next_call
    ensure_on_card(board, queued)
    unused = Word.system.where.not(id: @game.game_words.select(:word_id)).first
    queued.replace_word(unused)
    assert_equal unused.label, board.reload.square_for(queued.reload.game_word).label
  end

  test "external links only allow http and https" do
    @today.link_url = "javascript:alert(1)"
    @today.link_text = "Click"
    assert_not @today.valid?

    @today.link_url = "data:text/html;base64,xxx"
    assert_not @today.valid?

    @today.link_url = "https://example.com/events"
    assert @today.valid?
  end
end
