class Publications::TodaysController < Publications::BaseController
  # The publisher's home: the live game plus the on-deck draft. Before
  # the first launch there is no live game, just the draft to review.
  def show
    @publication.rotate_games
    @game = @publication.active_game
    @next_game = @publication.on_deck_game
    @tab = params[:tab] == "next" && @next_game ? :next : :current
    if @game
      @calls = @game.daily_calls.includes(:game_word)
      @call = @publication.current_call
      @next_call = @game.next_call
      @newsletter_block = NewsletterBlock.new(@publication)
      @claims_today = @call ? @call.daily_claims.count : 0
      @players = @publication.analytics.game_participants(@game)
      @claim_series = @publication.analytics.claims_per_day(@game)
        .select { |call, _count| call.called? }.last(7)
    end
  end
end
