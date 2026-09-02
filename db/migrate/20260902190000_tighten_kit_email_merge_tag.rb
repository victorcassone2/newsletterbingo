class TightenKitEmailMergeTag < ActiveRecord::Migration[8.1]
  # Liquid doesn't need the spaces, and a href value that carries them is
  # one careless paste away from being percent-encoded into text Kit
  # won't parse.
  def up
    execute <<~SQL
      UPDATE publications SET email_merge_tag = '{{subscriber.email_address|url_encode}}'
      WHERE email_merge_tag = '{{ subscriber.email_address | url_encode }}'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE publications SET email_merge_tag = '{{ subscriber.email_address | url_encode }}'
      WHERE email_merge_tag = '{{subscriber.email_address|url_encode}}'
    SQL
  end
end
