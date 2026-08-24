class Publications::Games::LaunchesController < Publications::Games::BaseController
  def create
    unless @publication.billing_active?
      back_to_game alert: "Set up billing to launch this game — it takes a minute from Setup → Billing."
      return
    end

    @game.launch
    notice = @publication.issue_cadence? ?
      "Your game is live. The first word goes out with your next send." :
      "Your game is live. Day 1 is #{@game.starts_on.strftime("%B %-d")}."
    back_to_game notice: notice
  rescue Game::NotLaunchable => error
    back_to_game alert: error.message
  rescue ActiveRecord::RecordNotUnique
    back_to_game alert: "A game is already running."
  end
end
