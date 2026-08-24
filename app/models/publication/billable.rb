# Billing lives on the account (see Account::Billable): one subscription,
# quantity = billable publications. A publication only knows two things --
# whether it rides free, and that changing the publication roster must
# re-point the subscription's quantity.
module Publication::Billable
  extend ActiveSupport::Concern

  included do
    # In-transaction callbacks on purpose: Solid Queue shares our database,
    # so the job row commits (or rolls back) atomically with the publication.
    after_create :sync_account_subscription_quantity
    after_destroy :sync_account_subscription_quantity
    after_update :sync_account_subscription_quantity, if: :saved_change_to_complimentary?
  end

  # The one question the game-rotation gate asks.
  def billing_active?
    complimentary? || account.subscribed?
  end

  private
    def sync_account_subscription_quantity
      account.sync_subscription_quantity_later if account.subscribed?
    end
end
