class Publications::AnalyticsController < Publications::BaseController
  def show
    @analytics = @publication.analytics
    @game = @publication.active_game
    @completed_games = @publication.games.completed.order(starts_on: :desc)
  end
end
