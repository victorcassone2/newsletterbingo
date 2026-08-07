class CreateSponsors < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsors, id: :uuid do |t|
      t.references :publication, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :website_url
      t.string :description
      t.datetime :archived_at

      t.timestamps
    end
  end
end
