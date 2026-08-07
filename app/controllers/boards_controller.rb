class BoardsController < PublicController
  def show
    if current_participant.nil?
      return render "boards/welcome"
    end

    @publication.close_finished_games
    @game = @publication.active_game || latest_played_game
    if @game.nil?
      return render "boards/welcome"
    end

    @board = current_participant.bingo_boards.find_by(game: @game)
    if @board.nil?
      return render "boards/welcome"
    end

    @squares = @board.bingo_squares.includes(game_word: { daily_call: :sponsor }).to_a
    @todays_call = @game.call_for(@publication.local_date)
    @claimed_today = @todays_call &&
      current_participant.daily_claims.exists?(daily_call_id: @todays_call.id)
    @claimed_count = @board.claimed_word_count
    @completed_lines = @board.completed_lines
    @line_prize = @game.line_prize
    @blackout_prize = @game.blackout_prize
    @celebrate = flash[:celebrate]
  end

  private
    def latest_played_game
      current_participant.bingo_boards.joins(:game)
        .merge(Game.order(starts_on: :desc)).first&.game
    end
end
