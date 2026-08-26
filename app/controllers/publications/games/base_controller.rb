class Publications::Games::BaseController < Publications::BaseController
  before_action :set_game

  private
    def set_game
      @game = @publication.games.find(params[:game_id])
    end

    # Edits to a call round-trip to the call's own page.
    def back_to_call(**options)
      redirect_to edit_account_publication_game_call_path(publication_id: @publication.id, game_id: @game.id, id: @call.id), **options
    end

    # The open game is managed from Today (drafts on its "next" tab)
    # while finished games keep their own page.
    def back_to_game(**options)
      if @game.completed?
        redirect_to account_publication_game_path(publication_id: @publication.id, id: @game.id), **options
      elsif @game.draft?
        redirect_to account_publication_today_path(publication_id: @publication.id, tab: "next"), **options
      else
        redirect_to account_publication_today_path(publication_id: @publication.id), **options
      end
    end
end
