class Publications::Games::Calls::WordsController < Publications::Games::BaseController
  before_action :set_call

  # Change which word is called on this (uncalled) day: either swap with
  # another uncalled call, or substitute a library word not yet in the game.
  def update
    if params[:swap_call_id].present?
      other = @game.daily_calls.find(params[:swap_call_id])
      @call.swap_word_with(other)
      redirect_back_to_source notice: "Swapped #{other.label} into Day #{@call.day_number}."
    elsif params[:word_id].present?
      word = @publication.eligible_words.find(params[:word_id])
      @call.replace_word(word)
      redirect_back_to_source notice: "Day #{@call.day_number} will call #{word.label}."
    else
      redirect_back_to_source alert: "Pick a word to swap in."
    end
  rescue DailyCall::WordLocked
    redirect_back_to_source alert: "That word has already been called and can't change."
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    redirect_back_to_source alert: "That word is already in this game."
  end

  private
    def set_call
      @call = @game.daily_calls.find(params[:call_id])
    end

    def redirect_back_to_source(**options)
      if params[:from] == "today"
        redirect_to account_publication_today_path(publication_id: @publication.id), **options
      else
        redirect_to edit_account_publication_game_call_path(publication_id: @publication.id, game_id: @game.id, id: @call.id), **options
      end
    end
end
