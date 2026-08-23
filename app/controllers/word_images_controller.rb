# The embed block's <img> points here: today's word, drawn in the
# publication's colors. no-cache keeps email image proxies (Gmail's)
# fetching the current word on every open instead of a stale copy.
class WordImagesController < PublicController
  def show
    expires_now
    send_data WordImage.new(@publication).png, type: "image/png", disposition: "inline"
  end
end
