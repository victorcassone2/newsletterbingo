# The reader board rendered from an in-memory sample: no participant, no
# board, no claim, no issue, and no game rotation. Shared by the preview a
# tester's own link opens and the one a publisher can hand to anyone.
module SamplePreviewing
  extend ActiveSupport::Concern

  private
    # The live game if there is one, otherwise the draft waiting behind
    # it, so a publisher previewing before their first send still sees
    # what word 1 will look like. A draft still short of a full word set
    # has nothing to deal.
    def previewable_game
      game = @publication.active_game || @publication.on_deck_game
      game if game && game.game_words.count == game.pool_size
    end

    # Before the first send there is no current call, so word 1 stands in:
    # it's the one the publisher is about to put in front of readers.
    def load_sample_board(game)
      @game = game
      @todays_call = game.current_call || game.daily_calls.first
      @board = BingoBoard.sample_for(game, through: @todays_call)
      @squares = @board.bingo_squares.sort_by(&:position)
      @claimed_today = @todays_call.present?
      @on_card_today = @todays_call && @board.covers?(@todays_call.game_word)
      @claimed_count = @board.claimed_word_count
      @completed_lines = @board.completed_lines
      @line_prize = @publication.line_prize
      @blackout_prize = @publication.blackout_prize
      @celebrate = nil
    end
end
