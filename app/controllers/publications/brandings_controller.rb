class Publications::BrandingsController < Publications::BaseController
  def edit
    @newsletter_block = NewsletterBlock.new(@publication)
  end

  def update
    if @publication.update(branding_params)
      redirect_to edit_account_publication_branding_path(publication_id: @publication.id), notice: "Branding saved."
    else
      @newsletter_block = NewsletterBlock.new(@publication)
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def branding_params
      params.require(:publication).permit(:primary_color, :accent_color, :background_color, :text_color, :logo)
    end
end
