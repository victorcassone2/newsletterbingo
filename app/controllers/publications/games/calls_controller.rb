class Publications::Games::CallsController < Publications::Games::BaseController
  before_action :set_call

  def edit
    @eligible_replacements = replacement_words
    @latest_issue = latest_issue
  end

  def update
    if @call.update(call_params)
      back_to_game notice: "Day #{@call.day_number} updated."
    else
      @eligible_replacements = replacement_words
      @latest_issue = latest_issue
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_call
      @call = @game.daily_calls.find(params[:id])
    end

    def latest_issue
      @game.issues.order(:created_at).last if @publication.issue_cadence?
    end

    def call_params
      params.require(:daily_call).permit(:description, :link_url, :link_text,
        :prize_call, :prize_description)
    end

    def replacement_words
      in_game = @game.game_words.pluck(:word_id)
      @publication.eligible_words.where.not(id: in_game).order(:label)
    end
end
