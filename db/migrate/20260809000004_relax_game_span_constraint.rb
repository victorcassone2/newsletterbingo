class RelaxGameSpanConstraint < ActiveRecord::Migration[8.1]
  # Games no longer span 24 consecutive calendar days: calendar cadence
  # skips non-send days and issue cadence is date-free until words go out.
  def up
    remove_check_constraint :games, name: "games_span_24_days"
    add_check_constraint :games, "ends_on >= starts_on", name: "games_span_forward"
  end

  def down
    remove_check_constraint :games, name: "games_span_forward"
    add_check_constraint :games, "ends_on = (starts_on + 23)", name: "games_span_24_days"
  end
end
