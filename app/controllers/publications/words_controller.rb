class Publications::WordsController < Publications::BaseController
  # The library as a curation tool: the custom-word goal up top, then the
  # word cloud grouped by state. Adds land via Turbo Stream so seeding
  # many words never leaves the page.
  def index
    @filter = params[:filter] == "system" ? "system" : "custom"
    @words = if @filter == "system"
      Word.system.active.order(:label)
    else
      @publication.words.order(:label)
    end
    load_word_stats
    @word = @publication.words.new
  end

  def create
    @word = @publication.words.new(word_params)
    if @word.save
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_to account_publication_words_path(publication_id: @publication.id), notice: "#{@word.label} added."
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("word-errors",
            helpers.tag.div(@word.errors.full_messages.to_sentence, class: "errors"))
        end
        format.html do
          redirect_to account_publication_words_path(publication_id: @publication.id),
            alert: @word.errors.full_messages.to_sentence
        end
      end
    end
  end

  private
    def load_word_stats
      ids = @words.map(&:id)
      @in_game_ids = GameWord.joins(:game).merge(Game.open).where(word_id: ids).distinct.pluck(:word_id).to_set
      @use_counts = GameWord.where(word_id: ids).group(:word_id).count
    end

    def word_params
      params.require(:word).permit(:label)
    end
end
