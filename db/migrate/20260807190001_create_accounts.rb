class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps
    end

    create_table :memberships, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    add_index :memberships, [ :account_id, :user_id ], unique: true
    add_check_constraint :memberships, "role IN ('owner', 'member')", name: "memberships_role_check"
  end
end
