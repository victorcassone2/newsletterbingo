class CreateLinkChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :link_checks, id: :uuid do |t|
      t.references :publication, null: false, type: :uuid, index: true
      t.string :email_value
      t.string :token_value
      t.timestamps
    end
  end
end
