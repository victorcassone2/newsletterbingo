require "test_helper"

class PrizeTest < ActiveSupport::TestCase
  setup do
    @publication = publications(:omaha)
    @game = create_running_game(@publication, starts_on: @publication.local_date - 10)
    @participant = Participant.locate_or_register(@publication, "reader@example.com")
    @board = @participant.board_for(@game)
  end

  test "a disabled prize never creates awards" do
    @game.prizes.create!(kind: "line", enabled: false)
    complete_first_row
    assert_equal 0, @participant.prize_awards.count
    assert @board.reload.bingo_achieved?, "achievement is still tracked without a prize"
  end

  test "first bingo awards the line prize exactly once" do
    @game.prizes.create!(kind: "line", enabled: true, name: "$25 Gift Card")
    complete_first_row
    assert_equal 1, @participant.prize_awards.line.count

    # a second completed line must not award again
    (5..9).each { |position| @board.square_at(position).update!(claimed_at: Time.current) }
    @board.refresh_achievements
    assert_equal 1, @participant.prize_awards.line.count
  end

  test "duplicate award attempts collapse into one" do
    prize = @game.prizes.create!(kind: "line", enabled: true, name: "$25 Gift Card")
    first = prize.award_to(@participant)
    second = prize.award_to(@participant)
    assert_equal first.id, second.id
  end

  test "blackout at 24 claims, not 23" do
    @game.prizes.create!(kind: "blackout", enabled: true, name: "Grand Prize")
    playable = @board.bingo_squares.reject(&:free?)
    playable.first(23).each { |square| square.update!(claimed_at: Time.current) }
    @board.refresh_achievements
    assert_not @board.reload.blackout_achieved?
    assert_equal 0, @participant.prize_awards.blackout.count

    playable.last.update!(claimed_at: Time.current)
    @board.refresh_achievements
    assert @board.reload.blackout_achieved?
    assert_equal 1, @participant.prize_awards.blackout.count
  end

  test "a participant can hold both line and blackout awards" do
    @game.prizes.create!(kind: "line", enabled: true, name: "Line")
    @game.prizes.create!(kind: "blackout", enabled: true, name: "Blackout")
    @board.bingo_squares.reject(&:free?).each { |square| square.update!(claimed_at: Time.current) }
    @board.refresh_achievements
    assert_equal %w[ blackout line ], @participant.prize_awards.pluck(:kind).sort
  end

  test "prizes require a name when enabled" do
    prize = @game.prizes.new(kind: "line", enabled: true)
    assert_not prize.valid?
    prize.name = "Something nice"
    assert prize.valid?
  end

  test "prize links only allow http and https" do
    prize = @game.prizes.new(kind: "line", enabled: true, name: "P", link_url: "javascript:alert(1)")
    assert_not prize.valid?
  end

  private
    def complete_first_row
      (0..4).each { |position| @board.square_at(position).update!(claimed_at: Time.current) }
      @board.refresh_achievements
    end
end
