# Idempotency ledger for Stripe webhooks: the unique index on event_id is
# what lets ProcessedWebhookEvent.once tell a redelivery from a first
# delivery. Deliberately no account_id -- Stripe events are resolved to a
# tenant by the handler, not scoped at the ledger.
class CreateProcessedWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_webhook_events, id: :uuid do |t|
      t.string :event_id, null: false
      t.timestamps
    end
    add_index :processed_webhook_events, :event_id, unique: true
  end
end
