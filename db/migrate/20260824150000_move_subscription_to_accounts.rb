# One subscription per account, quantity = billable publications, instead of
# one subscription per publication. Billing state moves up to accounts and the
# per-publication columns (including the legacy app-side trial) go away.
class MoveSubscriptionToAccounts < ActiveRecord::Migration[8.1]
  def up
    add_column :accounts, :stripe_subscription_id, :string
    add_column :accounts, :subscription_status, :string
    add_column :accounts, :subscription_current_period_end, :datetime
    add_column :accounts, :subscription_cancel_at_period_end, :boolean, default: false, null: false
    add_index :accounts, :stripe_subscription_id

    # Best effort: promote each account's healthiest publication subscription.
    # Accounts holding several live per-publication subscriptions need their
    # extras canceled in the Stripe dashboard by hand.
    execute <<~SQL
      UPDATE accounts SET
        stripe_subscription_id = best.stripe_subscription_id,
        subscription_status = best.subscription_status,
        subscription_current_period_end = best.subscription_current_period_end,
        subscription_cancel_at_period_end = best.subscription_cancel_at_period_end
      FROM (
        SELECT DISTINCT ON (account_id) account_id, stripe_subscription_id,
          subscription_status, subscription_current_period_end, subscription_cancel_at_period_end
        FROM publications
        WHERE stripe_subscription_id IS NOT NULL
        ORDER BY account_id,
          CASE subscription_status
            WHEN 'active' THEN 0 WHEN 'trialing' THEN 1 WHEN 'past_due' THEN 2 ELSE 3
          END
      ) best
      WHERE accounts.id = best.account_id
    SQL

    remove_index :publications, :stripe_subscription_id
    remove_column :publications, :stripe_subscription_id
    remove_column :publications, :subscription_status
    remove_column :publications, :subscription_current_period_end
    remove_column :publications, :subscription_cancel_at_period_end
    remove_column :publications, :trial_ends_at
  end

  def down
    add_column :publications, :stripe_subscription_id, :string
    add_column :publications, :subscription_status, :string
    add_column :publications, :subscription_current_period_end, :datetime
    add_column :publications, :subscription_cancel_at_period_end, :boolean, default: false, null: false
    add_column :publications, :trial_ends_at, :datetime
    add_index :publications, :stripe_subscription_id

    remove_index :accounts, :stripe_subscription_id
    remove_column :accounts, :stripe_subscription_id
    remove_column :accounts, :subscription_status
    remove_column :accounts, :subscription_current_period_end
    remove_column :accounts, :subscription_cancel_at_period_end
  end
end
