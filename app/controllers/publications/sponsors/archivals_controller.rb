class Publications::Sponsors::ArchivalsController < Publications::BaseController
  before_action :set_sponsor

  def create
    @sponsor.archive
    redirect_to account_publication_sponsors_path(publication_id: @publication.id), notice: "#{@sponsor.name} archived."
  end

  def destroy
    @sponsor.unarchive
    redirect_to account_publication_sponsors_path(publication_id: @publication.id), notice: "#{@sponsor.name} restored."
  end

  private
    def set_sponsor
      @sponsor = @publication.sponsors.find(params[:sponsor_id])
    end
end
