# Each publication carries its own Stripe subscription. Status and renewal
# date are local columns synced from webhooks so no request path ever asks
# Stripe "is this publication paid?".
class AddBillingToPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :publications, :stripe_subscription_id, :string
    add_column :publications, :subscription_status, :string
    add_column :publications, :subscription_current_period_end, :datetime
    add_column :publications, :trial_ends_at, :datetime
    add_column :publications, :complimentary, :boolean, default: false, null: false
    add_index :publications, :stripe_subscription_id

    # Existing publications get the same 30-day runway a new signup would.
    reversible do |dir|
      dir.up { execute "UPDATE publications SET trial_ends_at = now() + interval '30 days'" }
    end
  end
end
