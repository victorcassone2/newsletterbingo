class Publications::Games::LaunchesController < Publications::Games::BaseController
  def create
    @game.launch
    back_to_game notice: "#{@game.name} is live. Day 1 is #{@game.starts_on.strftime("%B %-d")}."
  rescue Game::NotLaunchable => error
    back_to_game alert: error.message
  end
end
