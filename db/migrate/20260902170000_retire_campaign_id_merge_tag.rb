class RetireCampaignIdMergeTag < ActiveRecord::Migration[8.1]
  # beehiiv never had a campaign-id merge tag: {{campaign_id}} was invented
  # here and reaches readers unreplaced, so it proves nothing and no click
  # can claim. Its send-date tag does prove a send, always renders, and
  # gives the game the one-word-a-day cadence it already wants.
  def up
    change_column_default :publications, :campaign_merge_tag, from: "{{campaign_id}}", to: "{{current_date_ymd}}"
    execute "UPDATE publications SET campaign_merge_tag = '{{current_date_ymd}}' WHERE campaign_merge_tag = '{{campaign_id}}'"
  end

  def down
    change_column_default :publications, :campaign_merge_tag, from: "{{current_date_ymd}}", to: "{{campaign_id}}"
    execute "UPDATE publications SET campaign_merge_tag = '{{campaign_id}}' WHERE campaign_merge_tag = '{{current_date_ymd}}'"
  end
end
