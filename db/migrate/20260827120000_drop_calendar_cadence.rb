class DropCalendarCadence < ActiveRecord::Migration[8.1]
  # One cadence now: words advance per send. Publications whose platform
  # has no campaign id leave campaign_merge_tag blank, which is what tells
  # us to infer a send from the first click after the interval floor.
  def up
    remove_column :publications, :cadence
    remove_column :publications, :send_days
    change_column_null :publications, :campaign_merge_tag, true
  end

  def down
    add_column :publications, :cadence, :string, null: false, default: "issues"
    add_column :publications, :send_days, :integer, array: true, null: false, default: [ 0, 1, 2, 3, 4, 5, 6 ]
    execute "UPDATE publications SET campaign_merge_tag = '{{campaign_id}}' WHERE campaign_merge_tag IS NULL"
    change_column_null :publications, :campaign_merge_tag, false
  end
end
