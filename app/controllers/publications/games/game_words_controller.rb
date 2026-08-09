class Publications::Games::GameWordsController < Publications::Games::BaseController
  before_action :ensure_draft

  # The picker: choose a library word to take this slot.
  def edit
    @game_word = @game.game_words.find(params[:id])
    @choices = replacement_choices
  end

  # Replace a single word while the game is still a draft.
  def update
    game_word = @game.game_words.find(params[:id])
    word = @publication.eligible_words.find(params[:word_id])
    game_word.update!(word: word, label: word.label)
    back_to_game notice: "Word replaced with #{word.label}."
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    back_to_game alert: "That word is already in this game."
  end

  private
    def ensure_draft
      unless @game.draft?
        back_to_game alert: "Words are locked once a game launches. Change words from the schedule instead."
      end
    end

    def replacement_choices
      @publication.eligible_words.where.not(id: @game.game_words.select(:word_id))
        .search(params[:q]).order(:label)
    end
end
