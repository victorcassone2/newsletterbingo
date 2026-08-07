class Publications::WordsController < Publications::BaseController
  def index
    @filter = params[:filter] == "system" ? "system" : "custom"
    scope = @filter == "system" ? Word.system : @publication.words
    @words = scope.search(params[:q]).order(:label)
    @word = @publication.words.new
  end

  def create
    @word = @publication.words.new(word_params)
    if @word.save
      redirect_to account_publication_words_path(publication_id: @publication.id), notice: "#{@word.label} added."
    else
      redirect_to account_publication_words_path(publication_id: @publication.id),
        alert: @word.errors.full_messages.to_sentence
    end
  end

  private
    def word_params
      params.require(:word).permit(:label)
    end
end
