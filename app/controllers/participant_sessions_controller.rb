# Opens a reader's card without the email link: enter the address the
# newsletter arrives at, see your board. Viewing only: claiming still
# requires the token carried by the current send's bingo button. Lookup
# never registers: cards are created by a first claim, so a stranger's
# typo shouldn't mint phantom participants.
class ParticipantSessionsController < PublicController
  rate_limit to: 10, within: 1.minute, only: :create

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
end
