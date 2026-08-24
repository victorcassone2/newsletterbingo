# Calendar sends now register their campaign token as an Issue bound to
# the day's call, and one day can see several legitimate sends (test
# send, resend), so a call may carry more than one issue.
class AllowMultipleIssuesPerDailyCall < ActiveRecord::Migration[8.1]
  def change
    remove_index :issues, :daily_call_id, unique: true
    add_index :issues, :daily_call_id
  end
end
