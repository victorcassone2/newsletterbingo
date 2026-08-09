class Publications::GamesController < Publications::BaseController
  before_action :set_game, only: %i[ show edit update ]

  def index
    @publication.close_finished_games
    @games = @publication.games.order(starts_on: :desc)
    @open_game = @publication.open_game
  end

  # The open game lives on Today; this page is history for finished games.
  def show
    @publication.close_finished_games
    @game.reload
    if @game.draft? || @game.active?
      redirect_to account_publication_today_path(publication_id: @publication.id)
    else
      @calls = @game.daily_calls.includes(:game_word, :sponsor)
    end
  end

  def new
    @publication.close_finished_games
    if @publication.open_game
      redirect_to account_publication_today_path(publication_id: @publication.id),
        alert: "Finish the current game before starting a new one."
    else
      @game = @publication.games.new(starts_on: @publication.local_date)
    end
  end

  def create
    @game = @publication.games.new(game_params)
    @game.starts_on = @publication.local_date if @publication.issue_cadence?
    if @publication.calendar_cadence? && @game.starts_on.present? && @game.starts_on < @publication.local_date
      @game.errors.add(:starts_on, "can't be in the past")
      return render :new, status: :unprocessable_entity
    end
    if @game.save
      @game.regenerate_words
      @game.prizes.create!(kind: "line")
      @game.prizes.create!(kind: "blackout")
      redirect_to account_publication_today_path(publication_id: @publication.id),
        notice: "Review the 24 words and prizes, then launch when ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @game.draft? || game_params.keys == [ "name" ]
      if @game.update(game_params)
        redirect_to account_publication_today_path(publication_id: @publication.id), notice: "Game updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to account_publication_today_path(publication_id: @publication.id),
        alert: "Only the name can change after launch."
    end
  end

  private
    def set_game
      @game = @publication.games.find(params[:id])
    end

    def game_params
      params.require(:game).permit(:name, :starts_on)
    end
end
