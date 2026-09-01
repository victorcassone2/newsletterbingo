class Publications::Games::LaunchesController < Publications::Games::BaseController
  def create
    unless @publication.billing_active?
      back_to_game alert: launch_blocked_message
      return
    end

    @game.launch
    back_to_game notice: "Your game is live. The first word goes out with your next send."
  rescue Game::NotLaunchable => error
    back_to_game alert: error.message
  rescue ActiveRecord::RecordNotUnique
    back_to_game alert: "A game is already running."
  end

  private
    # Two different fixes, so two different messages: a canceled publication
    # is restored from Billing, a lapsed account subscribes there. Canceled
    # publications get no new game, since it couldn't finish before the
    # lights go out.
    def launch_blocked_message
      if @publication.canceled?
        "#{@publication.name} is cancelled. Restore it from the Billing page to run games again."
      else
        "Start your subscription to launch this game. It takes a minute from the Billing page."
      end
    end
end
