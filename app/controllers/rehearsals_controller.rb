# The preview a tester's bingo link opens instead of claiming. Nothing is
# created and the game stays exactly where it was: the campaign token is
# left unspent, so the real send still draws the next word.
#
# Read-only on purpose. It doesn't even rotate games, so nothing a test
# send does can nudge the schedule.
class RehearsalsController < PublicController
  include SamplePreviewing

  def show
    game = previewable_game
    if game.nil?
      flash[:claim_notice] = "There's no game to preview yet. Fill your word library and we'll draft one."
      return redirect_to board_path(@publication.public_code)
    end

    @rehearsal = flash[:rehearsal] == "listed" ? :listed : :shared
    load_sample_board(game)
    render "boards/show"
  end
end
