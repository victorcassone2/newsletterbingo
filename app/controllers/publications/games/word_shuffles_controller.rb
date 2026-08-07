class Publications::Games::WordShufflesController < Publications::Games::BaseController
  def create
    @game.regenerate_words
    back_to_game notice: "Words regenerated."
  rescue Game::NotLaunchable
    back_to_game alert: "Words are locked once a game launches."
  end
end
