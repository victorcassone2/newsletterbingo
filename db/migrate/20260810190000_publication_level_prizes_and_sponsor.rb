class PublicationLevelPrizesAndSponsor < ActiveRecord::Migration[8.1]
  # Prizes and the "Brought to you by" sponsor become always-on publication
  # setup instead of per-game records, and the Sponsor directory (with its
  # per-call attachments) goes away entirely.
  def up
    add_column :publications, :sponsor_name, :string
    add_column :prize_awards, :prize_name, :string
    add_column :prizes, :publication_id, :uuid

    # Snapshot what each award actually won before prize rows move around.
    execute <<~SQL
      UPDATE prize_awards SET prize_name = prizes.name
      FROM prizes WHERE prizes.id = prize_awards.prize_id
    SQL

    execute <<~SQL
      UPDATE prizes SET publication_id = games.publication_id
      FROM games WHERE games.id = prizes.game_id
    SQL

    # Each publication keeps one prize pair: the active game's, else the
    # newest game's. Awards re-point to the surviving row of their kind.
    execute <<~SQL
      CREATE TEMP TABLE chosen_games AS
      SELECT DISTINCT ON (publication_id) publication_id, id AS game_id
      FROM games
      ORDER BY publication_id, (status = 'active')::int DESC, created_at DESC
    SQL
    execute <<~SQL
      UPDATE prize_awards SET prize_id = survivor.id
      FROM games award_game
      JOIN chosen_games ON chosen_games.publication_id = award_game.publication_id
      JOIN prizes survivor ON survivor.game_id = chosen_games.game_id
      WHERE award_game.id = prize_awards.game_id AND survivor.kind = prize_awards.kind
    SQL
    execute <<~SQL
      DELETE FROM prizes WHERE game_id NOT IN (SELECT game_id FROM chosen_games)
    SQL

    # Every publication gets its two rows even if it never had a game.
    execute <<~SQL
      INSERT INTO prizes (id, publication_id, kind, enabled, link_clicks_count, created_at, updated_at)
      SELECT gen_random_uuid(), publications.id, kinds.kind, false, 0, now(), now()
      FROM publications
      CROSS JOIN (VALUES ('line'), ('blackout')) AS kinds(kind)
      WHERE NOT EXISTS (
        SELECT 1 FROM prizes
        WHERE prizes.publication_id = publications.id AND prizes.kind = kinds.kind
      )
    SQL

    change_column_null :prizes, :publication_id, false
    add_index :prizes, [ :publication_id, :kind ], unique: true
    add_foreign_key :prizes, :publications
    remove_column :prizes, :game_id
    remove_column :prizes, :sponsor_id

    remove_column :games, :sponsor_name
    remove_column :daily_calls, :sponsor_id
    drop_table :sponsors
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
