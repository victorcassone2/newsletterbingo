class Publications::SponsorsController < Publications::BaseController
  # The publication's standing "Sponsored by" line, managed from the
  # Sponsors & Prizes page.
  def update
    @publication.update!(sponsor_name: params.dig(:publication, :sponsor_name))
    redirect_to account_publication_prizes_path(publication_id: @publication.id),
      notice: "Sponsor saved."
  end
end
