class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues, id: :uuid do |t|
      t.uuid :game_id, null: false
      t.uuid :daily_call_id, null: false
      t.string :token, null: false
      t.date :called_on, null: false
      t.timestamps
    end

    # First writer wins: the unique token index makes concurrent first
    # opens of the same send collapse into a single advance.
    add_index :issues, %i[ game_id token ], unique: true
    add_index :issues, :daily_call_id, unique: true
    add_index :issues, :game_id
  end
end
