class DraftCallsForExistingDrafts < ActiveRecord::Migration[8.1]
  # Drafts now carry an undated call per word from the moment words are
  # assigned; give drafts created before this change their calls.
  def up
    execute <<~SQL
      INSERT INTO daily_calls (id, game_id, game_word_id, position, created_at, updated_at)
      SELECT gen_random_uuid(), game_words.game_id, game_words.id, game_words.position, now(), now()
      FROM game_words
      JOIN games ON games.id = game_words.game_id
      WHERE games.status = 'draft'
        AND NOT EXISTS (SELECT 1 FROM daily_calls WHERE daily_calls.game_id = game_words.game_id)
    SQL
  end

  def down
    execute <<~SQL
      DELETE FROM daily_calls
      USING games
      WHERE games.id = daily_calls.game_id AND games.status = 'draft'
    SQL
  end
end
