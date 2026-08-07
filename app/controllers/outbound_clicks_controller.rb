# Records a click, then redirects to the persisted, validated URL — never
# to anything supplied in the request, so open redirects are impossible.
# Content stays locked unless this participant actually earned it.
class OutboundClicksController < PublicController
  before_action :require_participant

  def call
    daily_call = DailyCall.joins(game: :publication)
      .where(publications: { id: @publication.id }).find(params[:id])
    claimed = current_participant.daily_claims.exists?(daily_call_id: daily_call.id)
    if daily_call.link? && claimed
      daily_call.record_link_click
      redirect_to daily_call.link_url, allow_other_host: true
    else
      redirect_to board_path(@publication.public_code)
    end
  end

  def prize
    prize = Prize.joins(game: :publication)
      .where(publications: { id: @publication.id }).find(params[:id])
    board = current_participant.bingo_boards.find_by(game: prize.game)
    earned = board && (prize.line? ? board.bingo_achieved? : board.blackout_achieved?)
    if prize.link_url.present? && earned
      prize.record_link_click
      redirect_to prize.link_url, allow_other_host: true
    else
      redirect_to board_path(@publication.public_code)
    end
  end

  private
    def require_participant
      redirect_to board_path(@publication.public_code) if current_participant.nil?
    end
end
