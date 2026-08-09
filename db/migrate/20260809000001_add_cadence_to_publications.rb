class AddCadenceToPublications < ActiveRecord::Migration[8.1]
  def up
    add_column :publications, :cadence, :string, null: false, default: "issues"
    add_column :publications, :send_days, :integer, array: true, null: false, default: [ 0, 1, 2, 3, 4, 5, 6 ]
    add_column :publications, :campaign_merge_tag, :string, null: false, default: "{{campaign_id}}"

    # Existing publications keep the behavior their live games were built on.
    execute "UPDATE publications SET cadence = 'calendar'"
  end

  def down
    remove_column :publications, :cadence
    remove_column :publications, :send_days
    remove_column :publications, :campaign_merge_tag
  end
end
