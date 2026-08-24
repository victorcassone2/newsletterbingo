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

  # The card a confirm-in-app subscription would charge: the customer's
  # chosen default, else the card Checkout attached. nil means hosted
  # Checkout must collect one. This is a live Stripe lookup -- admin-time
  # only (the confirm screen), never a reader path -- and it fails open to
  # Checkout on any Stripe hiccup.
  def stripe_payment_method
    return nil if stripe_customer_id.blank?

    customer = Payments.platform.retrieve_customer(stripe_customer_id)
    default_id = customer.try(:invoice_settings)&.try(:default_payment_method)
    methods = Payments.platform.list_payment_methods(stripe_customer_id).data
    methods.find { |method| method.id == default_id } || methods.first
  rescue Stripe::StripeError
    nil
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
