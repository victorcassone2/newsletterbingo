class CreateDailyClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_claims, id: :uuid do |t|
      t.references :participant, null: false, foreign_key: true, type: :uuid
      t.references :daily_call, null: false, foreign_key: true, type: :uuid
      t.references :game, null: false, foreign_key: true, type: :uuid
      t.datetime :claimed_at, null: false

      t.timestamps
    end

    add_index :daily_claims, [ :participant_id, :daily_call_id ], unique: true
    add_index :daily_claims, [ :game_id, :claimed_at ]
    add_index :daily_claims, [ :daily_call_id, :claimed_at ]
  end
end
