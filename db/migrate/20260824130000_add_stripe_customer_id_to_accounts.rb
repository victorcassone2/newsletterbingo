# One Stripe Customer per Account: a single card covers every publication
# an owner runs. Subscriptions hang off publications instead.
class AddStripeCustomerIdToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :stripe_customer_id, :string
    add_index :accounts, :stripe_customer_id
  end
end
