class Publications::Words::ArchivalsController < Publications::BaseController
  before_action :set_word

  def create
    @word.archive
    redirect_to account_publication_words_path(publication_id: @publication.id), notice: "#{@word.label} archived."
  end

  def destroy
    @word.unarchive
    redirect_to account_publication_words_path(publication_id: @publication.id), notice: "#{@word.label} restored."
  end

  private
    def set_word
      @word = @publication.words.find(params[:word_id])
    end
end
