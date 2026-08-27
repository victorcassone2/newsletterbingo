# The newsletter link itself performs the claim: one GET identifies the
# publication, proves the click came from the current send via its
# campaign token, claims the square, establishes the participant
# session, and redirects to a clean URL with no email in it.
#
# Links that can't claim (stale bookmarks, earlier sends, unreplaced
# merge tags) still land the reader on their board, with a notice
# explaining that only the current email's button claims.
class ClaimsController < PublicController
  rate_limit to: 60, within: 1.minute, only: :create

  def create
    email = params[:email].to_s.strip
    return land_without_claim(unreadable_email_message(email)) unless valid_email?(email)

    participant = Participant.locate_or_register(@publication, email)
    establish_participant_session(participant)

    @publication.rotate_games
    game = @publication.active_game
    return land_without_claim("There's no bingo game running right now. Check back soon!") if game.nil?

    call = game.claimable_call_for(params[:issue])
    return land_without_claim(not_claimable_message(game, params[:issue])) if call.nil?
    game = call.game # a rollover token lands on the successor game

    board_before = participant.bingo_boards.find_by(game: game)
    had_bingo = board_before&.bingo_achieved?
    had_blackout = board_before&.blackout_achieved?

    claim = call.claim_by(participant)
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
    land_without_claim("We couldn't read your email address from that link. Open today's email and tap the bingo button again.")
  rescue DailyCall::NotClaimable
    redirect_to board_path(@publication.public_code)
  end

  private
    def land_without_claim(message)
      flash[:claim_notice] = message
      redirect_to board_path(@publication.public_code)
    end

    def unreadable_email_message(email)
      if merge_tag_unreplaced?(email)
        "That link couldn't tell us who you are, so we can't find your card. Try tapping the bingo button in today's email again. If this keeps happening, reply to the newsletter so they can fix their bingo link."
      else
        "We couldn't read your email address from that link. Open today's email and tap the bingo button again."
      end
    end

    # The reader most likely tapped "Claim today's word" in an old email,
    # so say why nothing was claimed instead of silently showing the board.
    def not_claimable_message(game, token)
      token = token.to_s.strip
      if token.present? && !Issue.plausible_token?(token)
        "That link couldn't prove it came from the current email, so nothing was claimed. If this keeps happening, reply to the newsletter so they can fix their bingo link."
      elsif game.current_call
        "This link is from an earlier email, so nothing was claimed. The word can only be claimed from the bingo button in the latest newsletter."
      else
        "The game starts with the next newsletter. Watch your inbox!"
      end
    end

    def valid_email?(email)
      email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def merge_tag_unreplaced?(email)
      email.blank? || email.match?(/[{}|\[\]%]|MERGE|EMAIL\z/i) && !email.match?(URI::MailTo::EMAIL_REGEXP)
    end
end
