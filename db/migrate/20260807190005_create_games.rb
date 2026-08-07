class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games, id: :uuid do |t|
      t.references :publication, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_check_constraint :games, "ends_on = starts_on + 23", name: "games_span_24_days"
    add_check_constraint :games, "status IN ('draft', 'active', 'completed')", name: "games_status_check"
    add_index :games, :publication_id, unique: true, where: "status IN ('draft', 'active')",
      name: "index_games_one_open_per_publication"

    create_table :prizes, id: :uuid do |t|
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: false
      t.string :name
      t.string :description
      t.string :instructions
      t.string :link_url
      t.string :link_text
      t.references :sponsor, null: true, foreign_key: true, type: :uuid
      t.integer :link_clicks_count, null: false, default: 0

      t.timestamps
    end

    add_index :prizes, [ :game_id, :kind ], unique: true
    add_check_constraint :prizes, "kind IN ('line', 'blackout')", name: "prizes_kind_check"
  end
end
