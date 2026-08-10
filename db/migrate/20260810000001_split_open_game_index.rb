class SplitOpenGameIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :games, column: :publication_id, unique: true,
      where: "status IN ('draft','active')", name: "index_games_one_open_per_publication"
    add_index :games, :publication_id, unique: true,
      where: "status = 'active'", name: "index_games_one_active_per_publication"
    add_index :games, :publication_id, unique: true,
      where: "status = 'draft'", name: "index_games_one_draft_per_publication"
  end
end
