# What a bingo link actually carried when it arrived. Recorded from the
# clicks that can only be diagnostic: a listed tester's preview, and any
# link whose email address didn't survive its platform's replacement.
# One row per publication, replaced by the next click that says something
# new, so Setup can report the truth instead of asking the publisher to
# trust their paste.
#
# A merge tag the platform never replaced arrives verbatim, braces and
# all. That is the failure this record exists to make loud: a wrong tag
# breaks nothing visibly, it just quietly stops every claim.
class LinkCheck < ApplicationRecord
  belongs_to :publication

  # The address is proof on its own: an unreplaced tag can't look like one.
  def email_replaced?
    email_value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
  end

  # Untagged publications have no per-send value to replace, so there is
  # nothing here to be wrong.
  def token_expected?
    publication.campaign_tagged?
  end

  def token_replaced?
    Issue.plausible_token?(token_value.to_s.strip)
  end

  # Everything the claim link needed arrived replaced.
  def complete?
    email_replaced? && (!token_expected? || token_replaced?)
  end
end
