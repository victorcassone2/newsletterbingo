class Account::SyncSubscriptionQuantityJob < ApplicationJob
  # The account can vanish between enqueue and perform (account deletion
  # destroys its publications, each of which enqueues one of these).
  discard_on ActiveRecord::RecordNotFound

  def perform(account)
    account.sync_subscription_quantity!
  end
end
