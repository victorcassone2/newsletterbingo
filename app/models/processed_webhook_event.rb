class ProcessedWebhookEvent < ApplicationRecord
  # Internal control-flow signal for .once: the ledger insert hit the unique
  # index, meaning this event was already processed. Never leaves this class.
  class AlreadyProcessed < StandardError; end

  # No uniqueness validation here on purpose: duplicates must surface as
  # RecordNotUnique from the index so .once can tell "already processed" apart
  # from a handler failure. A validation would raise RecordInvalid instead and
  # blur that line.
  validates :event_id, presence: true

  # Idempotent webhook processing. Inserts the ledger row first; if the unique
  # index rejects it (a redelivered Stripe event), returns false without
  # running the block. Otherwise runs the block and returns its value. The
  # insert + block share a transaction so a failed block rolls the ledger row
  # back, leaving the event eligible for a genuine retry.
  #
  # Only the ledger insert's conflict is swallowed. Any error raised by the
  # block -- including RecordInvalid or RecordNotUnique from the handler's own
  # writes -- propagates, 500s the webhook, and keeps Stripe retrying. That is
  # deliberate: acking an event whose handler failed would silently drop it.
  def self.once(event_id)
    result = nil
    transaction do
      begin
        create!(event_id: event_id)
      rescue ActiveRecord::RecordNotUnique
        # The connection may be in an aborted transaction state (Postgres), so
        # issue no further SQL: unwind and roll back via the sentinel.
        raise AlreadyProcessed
      end
      result = yield
    end
    result
  rescue AlreadyProcessed
    false
  end
end
