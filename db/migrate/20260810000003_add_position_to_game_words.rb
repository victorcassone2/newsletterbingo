class AddPositionToGameWords < ActiveRecord::Migration[8.1]
  def up
    add_column :game_words, :position, :integer

    # Existing rows keep their creation order as the reveal order.
    execute <<~SQL
      UPDATE game_words SET position = numbered.row_number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY game_id ORDER BY created_at, id) AS row_number
        FROM game_words
      ) numbered
      WHERE game_words.id = numbered.id
    SQL

    change_column_null :game_words, :position, false
  end

  def down
    remove_column :game_words, :position
  end
end
