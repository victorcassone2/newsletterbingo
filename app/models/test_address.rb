# An address the publisher has declared a tester: their own, a seed list,
# an outside designer, anyone who receives the real newsletter but must
# never move the game. Bingo links clicked from here always open a
# preview instead of claiming.
#
# Nothing is a tester until it is listed here, so this list is the whole
# mechanism.
class TestAddress < ApplicationRecord
  LIMIT_PER_PUBLICATION = 25

  belongs_to :publication

  normalizes :email, with: ->(e) { e.strip.downcase }

  # Validated here so a repeat submit reads as a message rather than an
  # error, and backed by the database index for the race.
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { scope: :publication_id, message: "is already on the list" }
  validate :publication_has_room, on: :create

  private
    def publication_has_room
      if publication && publication.test_addresses.count >= LIMIT_PER_PUBLICATION
        errors.add(:base, "You can list up to #{LIMIT_PER_PUBLICATION} test addresses.")
      end
    end
end
