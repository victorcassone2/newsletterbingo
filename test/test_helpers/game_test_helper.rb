module GameTestHelper
  # A launched game in the publication's format, with its history already
  # sent. Launch dates nothing now: words go out one per send, so the
  # helper plays those sends itself, starting on starts_on and running a
  # day apart up to today. Pass issued: to send a different number.
  def create_running_game(publication, starts_on: publication.local_date, issued: nil)
    game = publication.games.create!(starts_on: starts_on)
    game.assign_words(Game.random_word_selection(publication, count: game.pool_size))
    if starts_on < publication.local_date
      travel_to(local_noon(publication, starts_on)) { game.launch }
    else
      game.launch
    end
    issue_words(game, from: starts_on, count: issued || sends_through_today(game, starts_on))
    game
  end

  # Sends the first `count` words that haven't gone out yet, one per
  # issue. Each issue is backdated past the interval floor, the way
  # db/seeds.rb does, so a fresh send can advance the game right away.
  def issue_words(game, from:, count:)
    game.daily_calls.first(count).each_with_index do |call, index|
      next if call.issued?
      called_on = from + index
      game.issues.create!(token: "helper-send-#{call.position}", daily_call: call, called_on: called_on,
        created_at: [ local_noon(game.publication, called_on), (Game::ISSUE_INTERVAL_FLOOR + 1.hour).ago ].min)
      call.update!(call_on: called_on)
    end
  end

  # Runs a game out: every word goes out, and the whole run is backdated
  # so the last one is past its grace period. Rotation retires a game in
  # this state on the next visit.
  def age_out_game(game)
    issue_words(game, from: game.starts_on, count: game.pool_size)
    last_sent_on = game.publication.local_date - (Game::LAST_ISSUE_OPEN_FOR + 1)
    shift = (last_sent_on - game.daily_calls.maximum(:call_on)).to_i
    game.daily_calls.each { |call| call.update_columns(call_on: call.call_on + shift) }
    game.issues.each { |issue| issue.update_columns(called_on: issue.called_on + shift) }
    game.update_columns(starts_on: game.daily_calls.minimum(:call_on), ends_on: last_sent_on)
    game.reload
  end

  # One send a day from starts_on through today, so a game started five
  # days ago is six words in. A start date still in the future has sent
  # nothing yet.
  def sends_through_today(game, starts_on)
    elapsed = (game.publication.local_date - starts_on).to_i + 1
    elapsed.clamp(0, game.pool_size)
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
