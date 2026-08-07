# Lightweight engagement metrics, all plain Rails queries against
# indexed columns. Instantiated via Publication#analytics.
class Publication::Analytics
  attr_reader :publication

  def initialize(publication)
    @publication = publication
  end

  def total_participants
    publication.participants.count
  end

  def claims_today
    publication.todays_call&.daily_claims&.count || 0
  end

  def claims_since(time)
    DailyClaim.joins(:game).where(games: { publication_id: publication.id }).where(claimed_at: time..).count
  end

  def claims_last_7_days = claims_since(7.days.ago)
  def claims_last_30_days = claims_since(30.days.ago)

  # --- Current game ---

  def game_participants(game)
    game.bingo_boards.count
  end

  def claims_per_day(game)
    counts = game.daily_claims.group(:daily_call_id).count
    game.daily_calls.map { |call| [ call, counts[call.id] || 0 ] }
  end

  def participation_rate_today(game)
    players = game_participants(game)
    players.zero? ? 0 : (claims_today * 100.0 / players).round
  end

  # Players who have claimed every call so far.
  def perfect_participation_count(game, date = publication.local_date)
    called = game.called_calls(date).count
    return 0 if called.zero?
    game.daily_claims.group(:participant_id).count.count { |_, claims| claims == called }
  end

  def bingo_winners(game)
    game.bingo_boards.where.not(bingo_achieved_at: nil).count
  end

  def blackout_winners(game)
    game.bingo_boards.where.not(blackout_achieved_at: nil).count
  end

  def line_prizes_awarded(game)
    game.prize_awards.line.count
  end

  def blackout_prizes_awarded(game)
    game.prize_awards.blackout.count
  end

  # --- Sponsors ---

  def sponsor_stats
    publication.sponsors.active.map do |sponsor|
      calls = sponsor.daily_calls
      {
        sponsor: sponsor,
        calls: calls.count,
        claims: DailyClaim.where(daily_call_id: calls.select(:id)).count,
        link_clicks: calls.sum(:link_clicks_count)
      }
    end
  end

  # --- Completed game summary ---

  def completed_game_summary(game)
    boards = game.bingo_boards.count
    claim_counts = game.daily_claims.group(:participant_id).count.values
    {
      participants: boards,
      average_claimed_days: claim_counts.any? ? (claim_counts.sum.to_f / claim_counts.size).round(1) : 0,
      median_claimed_days: median(claim_counts),
      bingo_percent: boards.zero? ? 0 : (bingo_winners(game) * 100.0 / boards).round,
      line_prizes: line_prizes_awarded(game),
      blackouts: blackout_winners(game),
      blackout_percent: boards.zero? ? 0 : (blackout_winners(game) * 100.0 / boards).round
    }
  end

  private
    def median(values)
      return 0 if values.empty?
      sorted = values.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]) / 2.0).round(1)
    end
end
