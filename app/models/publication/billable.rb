# Billing lives on the account (see Account::Billable): one subscription,
# quantity = billable publications. A publication only knows three things --
# whether it rides free, whether it's been canceled, and that changing the
# publication roster must re-point the subscription's quantity.
module Publication::Billable
  extend ActiveSupport::Concern

  included do
    # In-transaction callbacks on purpose: Solid Queue shares our database,
    # so the job row commits (or rolls back) atomically with the publication.
    after_create :sync_account_subscription_quantity
    after_destroy :sync_account_subscription_quantity
    after_update :sync_account_subscription_quantity, if: :saved_change_to_complimentary?
  end

  # The one question the game-rotation gate asks. A canceled publication is
  # already off the subscription and has a date it goes dark, so no new game
  # starts on it: the running one plays out and readers keep claiming until
  # the lights go off.
  def billing_active?
    !canceled? && (complimentary? || account.subscribed?)
  end

  # Canceling is a billing downgrade, and a subscription can't bill for zero:
  # the last publication the subscription pays for is shut down by canceling
  # the subscription itself, not one publication at a time.
  def closable?
    if account.subscribed?
      account.billable_publications.where.not(id: id).exists?
    else
      account.publications.uncanceled.where.not(id: id).exists?
    end
  end

  # Public because PublicationClosure calls it too: canceling and restoring
  # change the billable count exactly as much as adding or dropping one.
  def sync_account_subscription_quantity(prorate: true)
    account.sync_subscription_quantity_later(prorate: prorate) if account.subscribed?
  end
end
