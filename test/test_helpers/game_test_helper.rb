module GameTestHelper
  # A launched 24-day game with 24 words and 24 daily calls. Launch clamps
  # dates to today, so a past starts_on launches back then via time travel.
  def create_running_game(publication, starts_on: publication.local_date)
    game = publication.games.create!(starts_on: starts_on)
    game.assign_words(Game.random_word_selection(publication))
    if starts_on < publication.local_date
      travel_to(local_noon(publication, starts_on)) { game.launch }
    else
      game.launch
    end
    game
  end

  # The draft waiting behind the current game, fully formed.
  def create_on_deck_draft(publication)
    publication.rotate_games
    publication.on_deck_game
  end

  # Claim a specific (usually past) call directly, the way seeds do,
  # bypassing the today-only rule that claim_by enforces.
  def force_claim(call, participant, at: Time.current)
    board = participant.board_for(call.game)
    DailyClaim.create!(participant: participant, daily_call: call, game: call.game, claimed_at: at)
    board.square_for(call.game_word).update!(claimed_at: at)
    board.refresh_achievements
    board
  end

  # Noon in the publication's timezone on the given date.
  def local_noon(publication, date)
    publication.tz.local(date.year, date.month, date.day, 12)
  end
end
