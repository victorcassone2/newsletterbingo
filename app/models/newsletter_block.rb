# Builds the email-safe HTML block a publication pastes into its email.
# Table-based, inline CSS, no JavaScript. The click itself is the claim.
# The ESP's merge tags are inserted verbatim into the claim URL and
# replaced by the email platform at send time.
#
# The block is styled as a native section of the newsletter, the way
# Morning Brew runs trivia and 1440 runs polls: a bold section header
# under the Newsletter Bingo mark, one sentence of body copy, the claim
# as a text link, and the sponsor as a small credit line. No box, so it
# reads like the editor wrote it.
#
# The HTML is evergreen: pasted once, it never names a word, because the
# first click of a new send is what draws the next one. Platforms that
# stamp a campaign id per send get that merge tag in the claim URL, so
# the freshly stamped token proves a click came from the current email
# and stale bookmarks can look but not claim. Platforms without one
# (Substack, Ghost) get a link with no token, and the send is inferred
# from how long the publication has been quiet.
class NewsletterBlock
  include ERB::Util

  # The claim link is the one thing in the block that must never be hard
  # to see, so it wears the Newsletter Bingo amber rather than the
  # publication's accent. A publisher who picks a pale accent for their
  # board can't accidentally hide the link their whole game depends on.
  CLAIM_LINK_COLOR = "#f59e0b"

  attr_reader :publication

  def initialize(publication)
    @publication = publication
  end

  def claim_url(email_value = publication.email_merge_tag)
    url = "#{NewsletterBingo.public_host}/c/#{publication.public_code}/today?email=#{email_value}"
    url += "&issue=#{publication.campaign_merge_tag}" if publication.campaign_tagged?
    url
  end

  def sponsor_name
    publication.sponsor_name
  end

  # Safe to render directly: every dynamic value below is escaped with +h+.
  def to_html
    build_html.html_safe
  end

  private
    def build_html
      section_html(evergreen_sentence)
    end

    def section_html(sentence)
      head_margin = sponsor_name.present? ? "0 0 2px" : "0 0 8px"
      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:16px 0;">
          <tr>
            <td style="font-family:Helvetica,Arial,sans-serif;">
              <div style="font-size:17px;font-weight:bold;color:#{h publication.text_color};margin:#{head_margin};"><img src="#{h brand_icon_url}" alt="" width="15" height="15" border="0" style="vertical-align:-1px;">&nbsp; Today&#8217;s bingo</div>
              #{sponsor_row}
              <div style="font-size:14px;line-height:1.6;color:#{h publication.text_color};">#{sentence} <a href="#{h claim_url}" style="color:#{CLAIM_LINK_COLOR};font-weight:bold;text-decoration:none;white-space:nowrap;">Claim today&#8217;s spot &#8594;</a></div>
            </td>
          </tr>
        </table>
      HTML
    end

    def evergreen_sentence
      "A new word has dropped. One click puts it on your board."
    end

    def brand_icon_url
      "#{NewsletterBingo.public_host}/icon-192x192.png"
    end

    def sponsor_row
      if sponsor_name.present?
        %(<div style="font-size:12px;color:#{h publication.text_color};opacity:0.55;margin:0 0 8px;">Sponsored by #{h sponsor_name}</div>)
      else
        ""
      end
    end
end
