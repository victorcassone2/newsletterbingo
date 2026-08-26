class Publications::Games::Calls::WordsController < Publications::Games::BaseController
  before_action :set_call

  # Change which word this (uncalled) day calls: the typed label matches a
  # library word, or becomes a new custom word for the publication.
  def update
    if params[:label].present?
      word = locate_or_add_word(params[:label])
      @call.replace_word(word)
      back_to_call notice: "Now calling #{word.label}. Every board follows."
    else
      back_to_call alert: "Type a word to swap in."
    end
  rescue DailyCall::WordLocked
    back_to_call alert: "That word has already been called and can't change."
  rescue ActiveRecord::RecordNotUnique
    back_to_call alert: "That word is already in this game."
  rescue ActiveRecord::RecordInvalid => error
    back_to_call alert: error.record.errors.full_messages.to_sentence
  end

  private
    def set_call
      @call = @game.daily_calls.find(params[:call_id])
    end

    def locate_or_add_word(label)
      normalized = Word.normalize_value_for(:label, label)
      @publication.eligible_words.where("lower(label) = ?", normalized.to_s.downcase).first ||
        @publication.words.create!(label: label)
    end
end
