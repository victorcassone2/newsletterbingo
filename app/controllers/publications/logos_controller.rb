class Publications::LogosController < Publications::BaseController
  # The publication's logo, uploaded from the Branding pane. Removing it
  # puts the publication name back at the top of readers' boards.
  def destroy
    @publication.logo.purge
    redirect_to edit_account_publication_path(id: @publication.id, pane: "branding"),
      notice: "Logo removed."
  end
end
