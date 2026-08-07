class Publications::Games::CallsController < Publications::Games::BaseController
  before_action :set_call

  def edit
    @sponsors = @publication.sponsors.active.order(:name)
    @swappable_calls = @game.daily_calls.includes(:game_word).select(&:word_changeable?) - [ @call ]
    @eligible_replacements = replacement_words
  end

  def update
    if @call.update(call_params)
      redirect_back_to_source notice: "Day #{@call.day_number} updated."
    else
      @sponsors = @publication.sponsors.active.order(:name)
      @swappable_calls = @game.daily_calls.includes(:game_word).select(&:word_changeable?) - [ @call ]
      @eligible_replacements = replacement_words
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_call
      @call = @game.daily_calls.find(params[:id])
    end

    def call_params
      permitted = params.require(:daily_call).permit(:description, :link_url, :link_text,
        :sponsor_id, :prize_call, :prize_description)
      if permitted[:sponsor_id].present?
        permitted[:sponsor_id] = @publication.sponsors.find(permitted[:sponsor_id]).id
      else
        permitted[:sponsor_id] = nil
      end
      permitted
    end

    def replacement_words
      in_game = @game.game_words.pluck(:word_id)
      @publication.eligible_words.where.not(id: in_game).order(:label)
    end

    def redirect_back_to_source(**options)
      if params[:from] == "today"
        redirect_to account_publication_today_path(publication_id: @publication.id), **options
      else
        redirect_to account_publication_game_path(publication_id: @publication.id, id: @game.id), **options
      end
    end
end
