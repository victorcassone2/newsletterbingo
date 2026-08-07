class Publications::Games::GameWordsController < Publications::Games::BaseController
  # Replace a single word while the game is still a draft.
  def update
    unless @game.draft?
      return back_to_game alert: "Words are locked once a game launches. Change words from the schedule instead."
    end

    game_word = @game.game_words.find(params[:id])
    word = @publication.eligible_words.find(params[:word_id])
    game_word.update!(word: word, label: word.label)
    back_to_game notice: "Word replaced with #{word.label}."
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    back_to_game alert: "That word is already in this game."
  end
end
