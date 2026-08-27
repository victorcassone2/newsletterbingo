# Base for all reader-facing pages. No user authentication; participants
# are identified by a signed cookie set during the newsletter claim.
class PublicController < ApplicationController
  allow_unauthenticated_access

  layout "player"

  before_action :set_publication
  before_action :harden_privacy_headers

  private
    def set_publication
      @publication = Publication.playable.find_by(public_code: params[:public_code])
      render_unavailable("This bingo game isn't available right now.") if @publication.nil?
    end

    # Merge-tag links are weak authentication: never leak URLs onward and
    # keep reader pages out of search indexes.
    def harden_privacy_headers
      response.set_header("Referrer-Policy", "no-referrer")
      response.set_header("X-Robots-Tag", "noindex, nofollow")
    end

    def participant_cookie_key
      "bingo_participant_#{@publication.id}"
    end

    def establish_participant_session(participant)
      cookies.signed[participant_cookie_key] = {
        value: participant.public_token, expires: 90.days, httponly: true, same_site: :lax
      }
    end

    def current_participant
      return @current_participant if defined?(@current_participant)
      token = cookies.signed[participant_cookie_key]
      @current_participant = token.present? ? @publication.participants.find_by(public_token: token) : nil
    end
    helper_method :current_participant

    def render_unavailable(message, status: :not_found)
      @message = message
      render "public/unavailable", status: status, layout: "player"
    end
end
