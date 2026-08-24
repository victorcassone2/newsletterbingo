# One send of the newsletter, identified by the ESP's campaign token.
# Possession of the current send's token is what authorizes a claim, so
# every accepted token is recorded: the stored mapping keeps old emails
# resolving to the word they actually carried, no longer claimable.
# Under issue cadence the first request carrying an unseen token also
# advances the game to its next word; under calendar cadence the word is
# date-driven and the issue is purely the freshness record.
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
  # reader claims the word. Only issue-cadence games advance on tokens;
  # a calendar registration has no date of its own to give back.
  def rollbackable?
    game.issue_cadence? && game.issues.order(:created_at).last == self && daily_call.daily_claims.none?
  end

  # Puts the word back in the unissued queue.
  def rollback
    transaction do
      daily_call.update!(call_on: nil)
      destroy!
    end
  end
end
