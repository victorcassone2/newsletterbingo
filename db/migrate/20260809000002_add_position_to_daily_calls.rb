class AddPositionToDailyCalls < ActiveRecord::Migration[8.1]
  def up
    add_column :daily_calls, :position, :integer

    execute <<~SQL
      UPDATE daily_calls SET position = ranked.row_number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY game_id ORDER BY call_on) AS row_number
        FROM daily_calls
      ) ranked
      WHERE daily_calls.id = ranked.id
    SQL

    change_column_null :daily_calls, :position, false
    # Issue-cadence games date calls when their issue goes out, so call_on
    # is unknown until then — and two issues can share a calendar date.
    change_column_null :daily_calls, :call_on, true
    remove_index :daily_calls, name: "index_daily_calls_on_game_id_and_call_on"
    add_index :daily_calls, %i[ game_id call_on ]
    add_index :daily_calls, %i[ game_id position ], unique: true
  end

  def down
    remove_index :daily_calls, column: %i[ game_id position ]
    remove_index :daily_calls, column: %i[ game_id call_on ]
    add_index :daily_calls, %i[ game_id call_on ], unique: true
    change_column_null :daily_calls, :call_on, false
    remove_column :daily_calls, :position
  end
end
