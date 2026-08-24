module GameTestHelper
  # A launched game in the publication's format, fully worded and called.
  # Launch clamps dates to today, so a past starts_on launches back then
  # via time travel.
  def create_running_game(publication, starts_on: publication.local_date)
    game = publication.games.create!(starts_on: starts_on)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
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

  # Cards hold a random subset of the pool, so a given call may or may
  # not be on a given card. These force the outcome for deterministic
  # hit/miss expectations.
  def ensure_on_card(board, call)
    return if board.square_for(call.game_word)
    board.bingo_squares.reject(&:free?).first.update!(game_word: call.game_word)
    board.bingo_squares.reload
  end

  def ensure_off_card(board, call)
    square = board.square_for(call.game_word)
    return if square.nil?
    spare = board.game.game_words.where.not(id: board.bingo_squares.filter_map(&:game_word_id)).first
    square.update!(game_word: spare)
    board.bingo_squares.reload
  end

  # Claim a specific (usually past) call directly, the way seeds do,
  # bypassing the today-only rule that claim_by enforces.
  def force_claim(call, participant, at: Time.current)
    board = participant.board_for(call.game)
    ensure_on_card(board, call)
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
