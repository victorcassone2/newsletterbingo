require "mini_magick"

# Draws the current word as a transparent PNG in the publication's text
# color, so the newsletter block can show today's word without baking it
# into the email HTML. That makes the calendar-cadence block paste-once:
# the HTML never changes, the image is fetched fresh on every open.
#
# Two variants: :block is the fixed 480×88 canvas the boxed layout used;
# :inline is trimmed to the word's own bounds so it can sit inside a
# sentence at text height. Both render at 2× their display size.
class WordImage
  # Twice the 240×44 the email displays, for retina screens.
  WIDTH = 480
  HEIGHT = 88
  # Twice the 15px line the inline variant displays at.
  INLINE_HEIGHT = 30
  FONTS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",    # macOS
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", # Debian/Ubuntu
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"           # Fedora/Alpine
  ]

  attr_reader :publication, :label, :variant

  def initialize(publication, label: nil, variant: :block)
    @publication = publication
    @label = label || publication.current_call&.label || "TODAY'S WORD"
    @variant = variant
  end

  # PNG bytes, cached until the word or the branding changes.
  def png
    Rails.cache.fetch([ "word_image", publication.id, publication.text_color, label, variant ]) do
      render_png
    end
  end

  private
    def render_png
      Tempfile.create([ "word", ".png" ]) do |image|
        MiniMagick.convert do |convert|
          convert.background "none"
          convert.fill publication.text_color
          convert.font font if font
          convert.pointsize 60
          convert << "label:#{caption}"
          if variant == :inline
            convert.trim
            convert.resize "x#{INLINE_HEIGHT}"
          else
            convert.resize "#{WIDTH - 20}x#{HEIGHT - 12}>"
            convert.gravity "center"
            convert.extent "#{WIDTH}x#{HEIGHT}"
          end
          convert << image.path
        end
        File.binread(image.path)
      end
    end

    # ImageMagick reads a caption starting with "@" as a filename to load, so a
    # word like "@/etc/passwd" would become a file read. Passing the caption
    # through a temp file used to prevent that, but Debian and Ubuntu forbid
    # @-reads outright and took every word image down with them. A backslash
    # keeps the "@" literal on every platform.
    def caption
      label.sub(/\A@/) { "\\@" }
    end

    def font
      FONTS.find { |path| File.exist?(path) }
    end
end
