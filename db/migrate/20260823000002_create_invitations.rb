class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.string :email_address, null: false
      t.string :token, null: false

      t.timestamps

      t.index :account_id
      t.index :token, unique: true
      t.index [ :account_id, :email_address ], unique: true
    end
  end
end
