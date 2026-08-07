class CreateDailyCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_calls, id: :uuid do |t|
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.references :game_word, null: false, foreign_key: true, type: :uuid
      t.date :call_on, null: false
      t.text :description
      t.string :link_url
      t.string :link_text
      t.references :sponsor, null: true, foreign_key: true, type: :uuid
      t.boolean :prize_call, null: false, default: false
      t.string :prize_description
      t.integer :link_clicks_count, null: false, default: 0

      t.timestamps
    end

    add_index :daily_calls, [ :game_id, :call_on ], unique: true
    # Deferred so two uncalled calls can atomically swap words inside a transaction.
    add_unique_constraint :daily_calls, [ :game_id, :game_word_id ],
      deferrable: :deferred, name: "daily_calls_game_word_unique"
  end
end
