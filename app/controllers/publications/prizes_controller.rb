class Publications::PrizesController < Publications::BaseController
  # The Sponsorship page: the sponsor's whole footprint — their name and
  # where it appears, the standing prizes with award counts, and the
  # current game's prize calls.
  def index
    load_page
  end

  def update
    prize = @publication.prizes.find(params[:id])
    if prize.update(prize_params)
      redirect_to account_publication_prizes_path(publication_id: @publication.id),
        notice: "#{prize.kind.capitalize} prize saved."
    else
      load_page
      @errored_prize = prize
      render :index, status: :unprocessable_entity
    end
  end

  private
    def load_page
      @line_prize = @publication.line_prize
      @blackout_prize = @publication.blackout_prize
      @game = @publication.active_game
      @prize_calls = @game ? @game.daily_calls.where(prize_call: true).includes(:game_word) : DailyCall.none
    end

    def prize_params
      params.require(:prize).permit(:enabled, :name, :description, :instructions,
        :link_url, :link_text, :image)
    end
end
