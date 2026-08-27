# One send of the newsletter, identified by the ESP's campaign token.
# Possession of the current send's token is what authorizes a claim, so
# every accepted token is recorded: the stored mapping keeps old emails
# resolving to the word they actually carried, no longer claimable.
# The first request of a new send also advances the game to its next
# word. Publications whose platform has no campaign id get a token minted
# here instead, so the record still marks where each send started.
class Issue < ApplicationRecord
  belongs_to :game
  belongs_to :daily_call
  has_one :publication, through: :game

  validates :token, presence: true, uniqueness: { scope: :game_id }
  validates :called_on, presence: true

  # A token that looks like a real campaign id: not blank, not an
  # unreplaced merge tag ({{campaign_id}}, *|CAMPAIGN_UID|*, …).
  def self.plausible_token?(token)
    token.present? && token.length <= 120 && !token.match?(/[{}|\[\]%*\s]/)
  end

  # A spurious advance (test send, prank token) can be undone until a
  # reader claims the word.
  def rollbackable?
    game.issues.order(:created_at).last == self && daily_call.daily_claims.none?
  end

  # Puts the word back in the unissued queue.
  def rollback
    transaction do
      daily_call.update!(call_on: nil)
      destroy!
    end
  end
end
