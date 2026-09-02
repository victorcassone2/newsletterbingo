class Publications::PreviewLinksController < Publications::BaseController
  # Turning off every copy of the shared link at once: a new token means
  # the old URL stops resolving. Readers are untouched, since their claim
  # links never carried this token.
  def update
    @publication.regenerate_preview_token
    redirect_to edit_account_publication_path(id: @publication.id, pane: "testing"),
      notice: "New preview link. The old one no longer opens."
  end
end
