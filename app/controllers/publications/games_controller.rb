class Publications::GamesController < Publications::BaseController
  before_action :set_game, only: %i[ show ]

  # Games are never created by hand: rotation drafts the next one
  # automatically, and this index is history plus the current state.
  def index
    @publication.rotate_games
    @games = @publication.games.order(starts_on: :desc)
  end

  # The current game lives on Today; this page is history for finished games.
  def show
    @publication.rotate_games
    @game.reload
    if @game.draft? || @game.active?
      redirect_to account_publication_today_path(publication_id: @publication.id, tab: @game.draft? ? "next" : nil)
    else
      @calls = @game.daily_calls.includes(:game_word)
    end
  end

  private
    def set_game
      @game = @publication.games.find(params[:id])
    end
end
