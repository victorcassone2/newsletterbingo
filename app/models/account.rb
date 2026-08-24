class Account < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :users, through: :memberships
  has_many :publications, dependent: :destroy
  has_one :deactivation, class_name: "AccountDeactivation", dependent: :destroy

  validates :name, presence: true

  def owners
    users.merge(Membership.owner)
  end

  # Find-or-create the account's one Stripe Customer: a single card covers
  # every publication the account runs, and the Billing Portal shows all of
  # its subscriptions in one place.
  def ensure_stripe_customer!
    return stripe_customer_id if stripe_customer_id.present?

    customer = Payments.platform.create_customer(
      email: owners.first&.email_address,
      name: name,
      metadata: { account_id: id }
    )
    update!(stripe_customer_id: customer.id)
    customer.id
  end

  def deactivated?
    deactivation.present?
  end
end
