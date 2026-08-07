class CreateGameWords < ActiveRecord::Migration[8.1]
  def change
    create_table :game_words, id: :uuid do |t|
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.references :word, null: false, foreign_key: true, type: :uuid
      t.string :label, null: false

      t.timestamps
    end

    add_index :game_words, [ :game_id, :word_id ], unique: true
    add_index :game_words, "game_id, lower(label)", unique: true, name: "index_game_words_on_game_label"
  end
end
