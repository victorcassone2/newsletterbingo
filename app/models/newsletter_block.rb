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
# Both cadences get evergreen HTML, pasted once, and both carry the
# campaign-id merge tag: the freshly stamped token is what proves a click
# came from the current send, so stale bookmarks can look but not claim.
# Issue-cadence blocks carry no word (the first click of a new send
# advances the game). Calendar blocks show today's word through a
# dynamically served image (WordImage's inline variant), sized to sit
# inside the sentence at text height, so the HTML itself never changes.
class NewsletterBlock
  include ERB::Util

  attr_reader :publication

  def initialize(publication)
    @publication = publication
  end

  def claim_url(email_value = publication.email_merge_tag)
    "#{NewsletterBingo.public_host}/c/#{publication.public_code}/today?email=#{email_value}&issue=#{publication.campaign_merge_tag}"
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
      section_html(publication.issue_cadence? ? evergreen_sentence : daily_sentence)
    end

    def section_html(sentence)
      head_margin = sponsor_name.present? ? "0 0 2px" : "0 0 8px"
      <<~HTML
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:16px 0;">
          <tr>
            <td style="font-family:Helvetica,Arial,sans-serif;">
              <div style="font-size:17px;font-weight:bold;color:#{h publication.text_color};margin:#{head_margin};"><img src="#{h brand_icon_url}" alt="" width="15" height="15" border="0" style="vertical-align:-1px;">&nbsp; Today&#8217;s bingo</div>
              #{sponsor_row}
              <div style="font-size:14px;line-height:1.6;color:#{h publication.text_color};">#{sentence} <a href="#{h claim_url}" style="color:#{h publication.accent_color};font-weight:bold;text-decoration:none;white-space:nowrap;">Claim today&#8217;s spot &#8594;</a></div>
            </td>
          </tr>
        </table>
      HTML
    end

    def daily_sentence
      %(Today&#8217;s word is <img src="#{h word_image_url}" alt="today&#8217;s bingo word" height="15" border="0" style="height:15px;width:auto;vertical-align:-2px;">. One click puts it on your board.)
    end

    def evergreen_sentence
      "A new word drops with this issue, and the first click claims it."
    end

    def word_image_url
      "#{NewsletterBingo.public_host}/c/#{publication.public_code}/word.png?variant=inline"
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
