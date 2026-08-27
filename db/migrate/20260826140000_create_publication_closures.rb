class CreatePublicationClosures < ActiveRecord::Migration[8.1]
  def change
    create_table :publication_closures, id: :uuid do |t|
      t.uuid :publication_id, null: false
      # When the publication actually goes dark: the end of the period its
      # account has already paid for.
      t.datetime :closes_at, null: false

      t.timestamps

      t.index :publication_id, unique: true
    end
  end
end
