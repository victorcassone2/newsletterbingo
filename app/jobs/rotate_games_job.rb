class RotateGamesJob < ApplicationJob
  queue_as :default

  def perform
    Publication.active.find_each(&:rotate_games)
  end
end
