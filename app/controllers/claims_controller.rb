# The newsletter link itself performs the claim: one GET identifies the
# publication, proves the click came from the current send via its
# campaign token, claims the square, establishes the participant
# session, and redirects to a clean URL with no email in it.
#
# Links that can't claim (stale bookmarks, earlier sends, unreplaced
# merge tags) still land the reader on their board, with a notice
# explaining that only the current email's button claims.
#
# A click from a listed test address never claims at all: it opens a
# preview of the reader board and leaves the game exactly where it was,
# so a test send can be repeated as often as the publisher likes.
class ClaimsController < PublicController
  # Readers behind one corporate or carrier NAT all share an IP, and a send
  # lands them at once, so this cap guards against runaway traffic rather
  # than abuse: forcing the game forward is already floored at 12 hours in
  # Game#advance_to_next_word. Set it high enough that a crowd never trips
  # it, and land whoever does on their board instead of a bare 429.
  rate_limit to: 300, within: 1.minute, only: :create, with: :too_many_claims

  def create
    email = params[:email].to_s.strip
    return land_without_claim(unreadable_email_message(email)) unless valid_email?(email)
    return open_rehearsal if @publication.tester?(email)

    participant = Participant.locate_or_register(@publication, email)
    establish_participant_session(participant)

    @publication.rotate_games
    game = @publication.active_game
    return land_without_claim("There's no bingo game running right now. Check back soon!") if game.nil?

    call = game.claimable_call_for(params[:issue])
    return land_without_claim(not_claimable_message(game, params[:issue])) if call.nil?

    record_claim(call, participant, call.game) # a rollover token lands on the successor game
    redirect_to board_path(@publication.public_code)
  rescue ActiveRecord::RecordInvalid
    land_without_claim("We couldn't read your email address from that link. Open today's email and tap the bingo button again.")
  rescue DailyCall::NotClaimable
    redirect_to board_path(@publication.public_code)
  end

  private
    # The preview says which list caught the click, so a tester isn't left
    # wondering why nothing happened. The marker rides in the flash: it is
    # needed for exactly one redirect and nothing longer.
    def open_rehearsal
      flash[:rehearsal] = "listed"
      redirect_to rehearsal_path(@publication.public_code)
    end

    def record_claim(call, participant, game)
      board_before = participant.bingo_boards.find_by(game: game)
      had_bingo = board_before&.bingo_achieved?
      had_blackout = board_before&.blackout_achieved?

      claim = call.claim_by(participant)
      if claim.previously_new_record?
        board = participant.board_for(game)
        flash[:celebrate] = celebration_for(board, call, had_bingo: had_bingo, had_blackout: had_blackout)
      end
    end

    def celebration_for(board, call, had_bingo:, had_blackout:)
      if !had_blackout && board.blackout_achieved?
        "blackout"
      elsif !had_bingo && board.bingo_achieved?
        "bingo"
      elsif board.covers?(call.game_word)
        "claimed"
      else
        "off_card"
      end
    end

    def too_many_claims
      land_without_claim("We're seeing a lot of taps from your network at once. "\
        "Here's your board; tap the bingo button again in a minute to claim.")
    end

    def land_without_claim(message)
      flash[:claim_notice] = message
      redirect_to board_path(@publication.public_code)
    end

    def unreadable_email_message(email)
      if merge_tag_unreplaced?(email)
        "This link didn't carry an email address, so there was nothing to claim. That's expected in most test sends. If you're a reader and it keeps happening, reply to the newsletter so they can fix their bingo link."
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
