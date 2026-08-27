# A publication the publisher canceled, without touching the account's other
# publications. It comes off the subscription the moment it's canceled, but
# keeps running until closes_at: the end of the period already paid for.
class PublicationClosure < ApplicationRecord
  belongs_to :publication

  validates :publication_id, uniqueness: true

  # In-transaction callbacks on purpose, matching Publication::Billable:
  # Solid Queue shares our database, so the job row commits with the closure
  # or not at all.
  after_create :drop_from_subscription
  after_destroy :return_to_subscription

  # Canceled time has run out; the lights go off on their own, no job needed.
  def effective?
    closes_at <= Time.current
  end

  private
    # No proration on the way down: the publication runs to the end of the
    # period, so there's nothing to refund. The next invoice is simply
    # smaller.
    def drop_from_subscription
      publication.sync_account_subscription_quantity(prorate: false)
    end

    # Undoing a cancellation before the lights go out costs nothing extra:
    # that period was paid for and never refunded. Restoring one that
    # already went dark is prorated, because it's the same as adding a
    # publication back mid-period.
    def return_to_subscription
      publication.sync_account_subscription_quantity(prorate: effective?)
    end
end
