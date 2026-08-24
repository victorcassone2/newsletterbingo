require "test_helper"

class DailyCallTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, starts_on: @publication.local_date - 5)
    @participant = Participant.locate_or_register(@publication, "reader@example.com")
    @today = @game.call_for(@publication.local_date)
  end

  test "one call per game per date" do
    duplicate = @game.daily_calls.new(game_word: @game.game_words.first, call_on: @today.call_on)
    assert_not duplicate.valid?
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

  test "tomorrow cannot be claimed" do
    tomorrow = @game.call_for(@publication.local_date + 1)
    assert_raises(DailyCall::NotClaimable) { tomorrow.claim_by(@participant) }
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

  test "claim eligibility flips at midnight in the publication timezone" do
    game = @game
    aug_start = game.starts_on
    call = game.call_for(aug_start + 5)
    chicago = @publication.tz

    travel_to chicago.local(call.call_on.year, call.call_on.month, call.call_on.day, 23, 55) do
      assert call.claimable_now?
    end
    travel_to chicago.local(call.call_on.year, call.call_on.month, call.call_on.day, 23, 55) + 10.minutes do
      assert_not call.claimable_now?, "12:05 AM next day must not be claimable even if the server runs UTC"
    end
  end

  test "today's word locks once someone claims it" do
    assert @today.word_changeable?
    @today.claim_by(@participant)
    assert_not @today.reload.word_changeable?
    unused = Word.system.where.not(id: @game.game_words.select(:word_id)).first
    assert_raises(DailyCall::WordLocked) { @today.replace_word(unused) }
  end

  test "replacing a future word updates every board in place" do
    board = @participant.board_for(@game)
    tomorrow = @game.call_for(@publication.local_date + 1)
    ensure_on_card(board, tomorrow)
    unused = Word.system.where.not(id: @game.game_words.select(:word_id)).first
    tomorrow.replace_word(unused)
    assert_equal unused.label, board.reload.square_for(tomorrow.reload.game_word).label
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
