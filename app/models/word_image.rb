require "mini_magick"

# Draws the current word as a transparent PNG in the publication's text
# color, so the newsletter block can show today's word without baking it
# into the email HTML. That makes the calendar-cadence block paste-once:
# the HTML never changes, the image is fetched fresh on every open.
class WordImage
  # Twice the 240×44 the email displays, for retina screens.
  WIDTH = 480
  HEIGHT = 88
  FONTS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",    # macOS
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", # Debian/Ubuntu
    "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"           # Fedora/Alpine
  ]

  attr_reader :publication, :label

  def initialize(publication, label: nil)
    @publication = publication
    @label = label || publication.current_call&.label || "TODAY'S WORD"
  end

  # PNG bytes, cached until the word or the branding changes.
  def png
    Rails.cache.fetch([ "word_image", publication.id, publication.text_color, label ]) do
      render_png
    end
  end

  private
    def render_png
      # The label reaches ImageMagick through a file, never the command
      # line: a word like "@/etc/passwd" stays a literal caption instead
      # of becoming a file read.
      Tempfile.create([ "word", ".txt" ]) do |text|
        text.write(label)
        text.flush
        Tempfile.create([ "word", ".png" ]) do |image|
          MiniMagick.convert do |convert|
            convert.background "none"
            convert.fill publication.text_color
            convert.font font if font
            convert.pointsize 60
            convert << "label:@#{text.path}"
            convert.resize "#{WIDTH - 20}x#{HEIGHT - 12}>"
            convert.gravity "center"
            convert.extent "#{WIDTH}x#{HEIGHT}"
            convert << image.path
          end
          File.binread(image.path)
        end
      end
    end

    def font
      FONTS.find { |path| File.exist?(path) }
    end
end
