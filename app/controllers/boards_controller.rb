class BoardsController < PublicController
  def show
    if current_participant.nil?
      return render "boards/welcome"
    end

    @publication.rotate_games
    @board = board_in(@publication.active_game) || latest_played_board
    if @board.nil?
      return render "boards/welcome"
    end

    @game = @board.game
    @squares = @board.bingo_squares.includes(game_word: :daily_call).to_a
    @todays_call = @game.current_call
    @claimed_today = @todays_call &&
      current_participant.daily_claims.exists?(daily_call_id: @todays_call.id)
    @on_card_today = @todays_call && @board.covers?(@todays_call.game_word)
    @claimed_count = @board.claimed_word_count
    @completed_lines = @board.completed_lines
    @line_prize = @publication.line_prize
    @blackout_prize = @publication.blackout_prize
    @celebrate = flash[:celebrate]
  end

  private
    def board_in(game)
      game && current_participant.bingo_boards.find_by(game: game)
    end

    # With no gap between games, a reader who hasn't clicked into the new
    # game yet still sees their finished card, not a welcome screen.
    def latest_played_board
      current_participant.bingo_boards.joins(:game)
        .merge(Game.order(starts_on: :desc, created_at: :desc)).first
    end
end
