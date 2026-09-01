require "test_helper"

class ImageAttachableTest < ActiveSupport::TestCase
  setup { @publication = publications(:omaha) }

  test "a supported image attaches" do
    attach_logo "logo.png", "image/png"

    assert @publication.valid?
  end

  test "an unsupported content type is rejected" do
    attach_logo "logo.svg", "image/svg+xml"

    assert_not @publication.valid?
    assert_includes @publication.errors[:logo].to_sentence, "PNG"
  end

  # The uploader controls the declared type, so the size guard has to stand on
  # its own rather than lean on the format check.
  test "an oversized image is rejected" do
    attach_logo "logo.png", "image/png"
    @publication.logo.blob.byte_size = ImageAttachable::MAX_BYTE_SIZE + 1

    assert_not @publication.valid?
    assert_includes @publication.errors[:logo].to_sentence, "smaller than"
  end

  test "no attachment is fine" do
    assert @publication.valid?
  end

  private
    def attach_logo(name, content_type)
      @publication.logo.attach(
        io: File.open(Rails.root.join("test/fixtures/files", name)),
        filename: name,
        content_type: content_type
      )
    end
end
