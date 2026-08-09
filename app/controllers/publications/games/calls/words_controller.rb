class Publications::Games::Calls::WordsController < Publications::Games::BaseController
  before_action :set_call

  # Change which word is called on this (uncalled) day: either swap with
  # another uncalled call, or substitute a library word not yet in the game.
  def update
    if params[:swap_call_id].present?
      other = @game.daily_calls.find(params[:swap_call_id])
      @call.swap_word_with(other)
      back_to_game notice: "Swapped #{other.label} into Day #{@call.day_number}."
    elsif params[:word_id].present?
      word = @publication.eligible_words.find(params[:word_id])
      @call.replace_word(word)
      back_to_game notice: "Day #{@call.day_number} will call #{word.label}."
    else
      redirect_to edit_account_publication_game_call_path(publication_id: @publication.id, game_id: @game.id, id: @call.id),
        alert: "Pick a word to swap in."
    end
  rescue DailyCall::WordLocked
    back_to_game alert: "That word has already been called and can't change."
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    back_to_game alert: "That word is already in this game."
  end

  private
    def set_call
      @call = @game.daily_calls.find(params[:call_id])
    end
end
