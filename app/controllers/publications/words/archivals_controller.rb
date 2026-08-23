class Publications::Words::ArchivalsController < Publications::BaseController
  before_action :set_word

  def create
    @word.archive
    respond_with_chip notice: "#{@word.label} archived."
  end

  def destroy
    @word.unarchive
    respond_with_chip notice: "#{@word.label} restored."
  end

  private
    def set_word
      @word = @publication.words.find(params[:word_id])
    end

    # Swaps the chip in place and refreshes the goal meter, so archiving
    # never reloads the page or moves the scroll.
    def respond_with_chip(notice:)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(@word, partial: "publications/words/chip",
              locals: { word: @word, uses: @word.game_words.count }),
            turbo_stream.replace("word-goal", partial: "publications/words/goal")
          ]
        end
        format.html { redirect_to account_publication_words_path(publication_id: @publication.id), notice: notice }
      end
    end
end
