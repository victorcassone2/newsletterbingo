class Publications::TodaysController < Publications::BaseController
  # The publisher's home: the live game plus the on-deck draft. Before
  # the first launch there is no live game — just the draft to review.
  def show
    @publication.rotate_games
    @game = @publication.active_game
    @next_game = @publication.on_deck_game
    @tab = params[:tab] == "next" && @next_game ? :next : :current
    if @game
      @calls = @game.daily_calls.includes(:game_word)
      @call = @publication.current_call
      @next_call = @game.next_call
      @current_issue = @game.issues.order(:created_at).last if @publication.issue_cadence?
      @newsletter_block = NewsletterBlock.new(@publication, daily_call: @call)
      @claims_today = @call.daily_claims.count if @call
    end
  end
end
