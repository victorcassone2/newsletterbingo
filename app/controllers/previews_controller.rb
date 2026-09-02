# A sample card anyone can open, for the sponsor, designer or editor who
# only needs to see the game rather than receive the newsletter. The link
# carries a token the publisher can regenerate, so a copy that travels
# further than intended can be turned off without disturbing anything
# readers use.
class PreviewsController < PublicController
  include SamplePreviewing

  def show
    return render_unavailable("That preview link is no longer active.") unless token_matches?

    game = previewable_game
    if game.nil?
      flash[:claim_notice] = "#{@publication.name} hasn't drafted a game yet. Check back soon!"
      return redirect_to board_path(@publication.public_code)
    end

    @rehearsal = :shared
    load_sample_board(game)
    render "boards/show"
  end

  private
    def token_matches?
      params[:token].present? && params[:token] == @publication.preview_token
    end
end
