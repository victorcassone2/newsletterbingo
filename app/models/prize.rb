class Prize < ApplicationRecord
  KINDS = %w[ line blackout ]

  belongs_to :publication
  has_many :prize_awards, dependent: :restrict_with_error
  has_one_attached :image

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :publication_id }
  validates :name, presence: true, if: :enabled?
  validates :link_url, http_url: true

  def line? = kind == "line"
  def blackout? = kind == "blackout"

  # At most one award per participant, game, and kind, enforced by the
  # unique index, so simultaneous wins converge on a single award. The
  # prize name is snapshotted: this row is standing configuration, but
  # the award records what was actually won.
  def award_to(participant, game:)
    return nil unless enabled?

    PrizeAward.create_or_find_by!(participant: participant, game: game, kind: kind) do |award|
      award.prize = self
      award.prize_name = name
      award.awarded_at = Time.current
    end
  end

  def record_link_click
    self.class.where(id: id).update_all("link_clicks_count = link_clicks_count + 1")
  end
end
