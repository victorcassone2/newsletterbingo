class CreatePrizeAwards < ActiveRecord::Migration[8.1]
  def change
    create_table :prize_awards, id: :uuid do |t|
      t.references :participant, null: false, foreign_key: true, type: :uuid
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.references :prize, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.datetime :awarded_at, null: false

      t.timestamps
    end

    add_index :prize_awards, [ :participant_id, :game_id, :kind ], unique: true
    add_check_constraint :prize_awards, "kind IN ('line', 'blackout')", name: "prize_awards_kind_check"
  end
end
