# Cancellation happens in-app (cancel at period end) rather than in the
# Stripe portal, so the scheduled state needs a local column for the UI --
# same no-Stripe-on-request-paths rule as the rest of billing.
class AddCancelAtPeriodEndToPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :publications, :subscription_cancel_at_period_end, :boolean, default: false, null: false
  end
end
