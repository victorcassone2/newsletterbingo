# The newsletter link itself performs the claim: one GET identifies the
# publication, claims the current square, establishes the participant
# session, and redirects to a clean URL with no email in it.
#
# Issue-cadence publications also carry an issue token; the first click
# of a new send advances the game to its next word before claiming.
class ClaimsController < PublicController
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    email = params[:email].to_s.strip
    if merge_tag_unreplaced?(email)
      return render_unavailable("That link couldn't tell us who you are, so we can't find your card. Try tapping the bingo button in today's email again. If this keeps happening, reply to the newsletter so they can fix their bingo link.", status: :unprocessable_entity)
    end
    unless valid_email?(email)
      return render_unavailable("We couldn't read your email address from that link. Open today's email and tap the bingo button again.", status: :unprocessable_entity)
    end

    @publication.rotate_games
    game = @publication.active_game
    return render_unavailable("There's no bingo game running right now. Check back soon!") if game.nil?

    call = current_call_for(game)
    return render_unavailable(no_call_message(game)) if call.nil?
    game = call.game # an issue token can cross a game boundary

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
        elsif board.covers?(call.game_word) then "claimed"
        else "off_card"
        end
    end

    redirect_to board_path(@publication.public_code)
  rescue ActiveRecord::RecordInvalid
    render_unavailable("We couldn't read your email address from that link.", status: :unprocessable_entity)
  rescue DailyCall::NotClaimable
    redirect_to board_path(@publication.public_code)
  end

  private
    def current_call_for(game)
      if @publication.issue_cadence?
        game.call_for_issue(params[:issue])
      elsif game.started?
        game.call_for(@publication.local_date)
      end
    end

    def no_call_message(game)
      if @publication.issue_cadence?
        "The game starts with the next newsletter. Watch your inbox!"
      elsif !game.started?
        "This game starts #{game.starts_on.strftime("%B %-d")}. Come back on Day 1!"
      else
        "There's no bingo word today. Check back tomorrow!"
      end
    end

    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def merge_tag_unreplaced?(email)
      email.blank? || email.match?(/[{}|\[\]%]|MERGE|EMAIL\z/i) && !email.match?(URI::MailTo::EMAIL_REGEXP)
    end
end
