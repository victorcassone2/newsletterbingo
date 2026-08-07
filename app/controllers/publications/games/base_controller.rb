class Publications::Games::BaseController < Publications::BaseController
  before_action :set_game

  private
    def set_game
      @game = @publication.games.find(params[:game_id])
    end

    def back_to_game(**options)
      redirect_to account_publication_game_path(publication_id: @publication.id, id: @game.id), **options
    end
end
