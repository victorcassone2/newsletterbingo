class Publications::TodaysController < Publications::BaseController
  # The publisher's home: everything about the current game in one place.
  # Renders one of four states — no game, draft under review, live, or
  # live-but-not-started.
  def show
    @publication.close_finished_games
    @game = @publication.open_game
    if @game.nil?
      @last_game = @publication.games.completed.order(starts_on: :desc).first
    elsif @game.active?
      @calls = @game.daily_calls.includes(:game_word, :sponsor)
      @call = @publication.current_call
      @current_issue = @game.issues.order(:created_at).last if @publication.issue_cadence?
      @newsletter_block = NewsletterBlock.new(@publication, daily_call: @call)
      @claims_today = @call.daily_claims.count if @call
    end
  end
end
