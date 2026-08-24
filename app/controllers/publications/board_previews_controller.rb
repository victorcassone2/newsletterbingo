class Publications::BoardPreviewsController < Publications::BaseController
  layout "player"

  # A publisher's look at the real reader board, rendered from an
  # in-memory sample board so no participant or claims are created.
  # ?word=next shows the state after the next word goes out.
  def show
    @game = @publication.active_game
    if @game.nil?
      return redirect_to account_publication_today_path(publication_id: @publication.id),
        alert: "No live game to preview yet."
    end

    @todays_call = params[:word] == "next" ? @game.next_call : @game.current_call
    @board = BingoBoard.sample_for(@game, through: @todays_call)
    @squares = @board.bingo_squares.sort_by(&:position)
    @claimed_today = @todays_call.present?
    @on_card_today = @todays_call && @board.covers?(@todays_call.game_word)
    @claimed_count = @board.claimed_word_count
    @completed_lines = @board.completed_lines
    @line_prize = @publication.line_prize
    @blackout_prize = @publication.blackout_prize
    @celebrate = nil
    render "boards/show"
  end
end
