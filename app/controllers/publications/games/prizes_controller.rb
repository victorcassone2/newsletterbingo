class Publications::Games::PrizesController < Publications::Games::BaseController
  before_action :set_prize

  def edit
    @sponsors = @publication.sponsors.active.order(:name)
  end

  def update
    if @prize.update(prize_params)
      back_to_game notice: "#{@prize.kind.capitalize} prize saved."
    else
      @sponsors = @publication.sponsors.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_prize
      @prize = @game.prizes.find(params[:id])
    end

    def prize_params
      permitted = params.require(:prize).permit(:enabled, :name, :description, :instructions,
        :link_url, :link_text, :sponsor_id, :image)
      if permitted[:sponsor_id].present?
        permitted[:sponsor_id] = @publication.sponsors.find(permitted[:sponsor_id]).id
      else
        permitted[:sponsor_id] = nil
      end
      permitted
    end
end
