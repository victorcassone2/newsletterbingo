# Opens a reader's card without the email link: enter the address the
# newsletter arrives at, see your board. Viewing only: claiming still
# requires the token carried by the current send's bingo button. Lookup
# never registers: cards are created by a first claim, so a stranger's
# typo shouldn't mint phantom participants.
#
# A hit opens a board and a miss doesn't, so this form is unavoidably an
# oracle for "does this address read this publication?". No wording can
# hide that while the board still opens on the spot, so the defense is
# rate, not phrasing. The burst limit covers a reader fixing a typo; the
# hourly limit is what makes walking a publication's subscriber list
# through this form impractical.
class ParticipantSessionsController < PublicController
  rate_limit to: 10, within: 1.minute, name: "burst",
    with: :too_many_lookups, only: :create
  rate_limit to: 20, within: 1.hour, name: "sustained",
    with: :too_many_lookups, only: :create

  def create
    participant = @publication.participants.find_by(email: normalized_email)
    if participant
      establish_participant_session(participant)
    else
      flash[:claim_notice] = "We don't have a card for that address yet. Your card is created the first time you tap the bingo button in a #{@publication.name} email."
    end
    redirect_to board_path(@publication.public_code)
  end

  private
    def normalized_email
      Participant.normalize_value_for(:email, params[:email].to_s)
    end

    # Whoever trips this is far more likely to be a reader on a shared
    # connection than someone enumerating, so land them on the board the
    # way every other public path does rather than on a bare 429.
    def too_many_lookups
      flash[:claim_notice] = "That's a lot of card lookups from this connection. Give it a few minutes and try again."
      redirect_to board_path(@publication.public_code)
    end
end
