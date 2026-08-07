class Publications::TodaysController < Publications::BaseController
  def show
    @publication.close_finished_games
    @game = @publication.open_game
    @call = @publication.todays_call
    if @call
      @claims_today = @call.daily_claims.count
      @newsletter_block = NewsletterBlock.new(@publication, daily_call: @call)
      @sponsors = @publication.sponsors.active.order(:name)
    end
  end
end
