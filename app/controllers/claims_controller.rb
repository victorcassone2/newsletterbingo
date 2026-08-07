# The newsletter link itself performs the claim: one GET identifies the
# publication, claims today's square, establishes the participant session,
# and redirects to a clean URL with no email in it.
class ClaimsController < PublicController
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    email = params[:email].to_s.strip
    if merge_tag_unreplaced?(email)
      return render_unavailable("Your email platform didn't fill in your address. The publication needs to check its merge tag setting.", status: :unprocessable_entity)
    end
    unless valid_email?(email)
      return render_unavailable("We couldn't read your email address from that link. Open today's email and tap the bingo button again.", status: :unprocessable_entity)
    end

    game = @publication.active_game
    return render_unavailable("There's no bingo game running right now. Check back soon!") if game.nil?
    return render_unavailable("This game starts #{game.starts_on.strftime("%B %-d")}. Come back on Day 1!") unless game.started?
    if game.over?
      game.complete
      return render_unavailable("This game has finished. Watch the newsletter for the next one!")
    end

    call = game.call_for(@publication.local_date)
    return render_unavailable("There's no bingo word today. Check back tomorrow!") if call.nil?

    participant = Participant.locate_or_register(@publication, email)
    board_before = participant.bingo_boards.find_by(game: game)
    had_bingo = board_before&.bingo_achieved?
    had_blackout = board_before&.blackout_achieved?

    claim = call.claim_by(participant)
    establish_participant_session(participant)

    if claim.previously_new_record?
      board = participant.board_for(game)
      flash[:celebrate] =
        if !had_blackout && board.blackout_achieved? then "blackout"
        elsif !had_bingo && board.bingo_achieved? then "bingo"
        else "claimed"
        end
    end

    redirect_to board_path(@publication.public_code)
  rescue ActiveRecord::RecordInvalid
    render_unavailable("We couldn't read your email address from that link.", status: :unprocessable_entity)
  rescue DailyCall::NotClaimable
    redirect_to board_path(@publication.public_code)
  end

  private
    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def merge_tag_unreplaced?(email)
      email.blank? || email.match?(/[{}|\[\]%]|MERGE|EMAIL\z/i) && !email.match?(URI::MailTo::EMAIL_REGEXP)
    end
end
