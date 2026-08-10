class Publications::PrizesController < Publications::BaseController
  # The Sponsors & Prizes page: standing setup that applies to the current
  # game and every one after it.
  def index
    @line_prize = @publication.line_prize
    @blackout_prize = @publication.blackout_prize
  end

  def update
    prize = @publication.prizes.find(params[:id])
    if prize.update(prize_params)
      redirect_to account_publication_prizes_path(publication_id: @publication.id),
        notice: "#{prize.kind.capitalize} prize saved."
    else
      @line_prize = @publication.line_prize
      @blackout_prize = @publication.blackout_prize
      @errored_prize = prize
      render :index, status: :unprocessable_entity
    end
  end

  private
    def prize_params
      params.require(:prize).permit(:enabled, :name, :description, :instructions,
        :link_url, :link_text, :image)
    end
end
