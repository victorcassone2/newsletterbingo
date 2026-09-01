# Size and format guards for an attached image. Active Storage stores
# whatever the form hands it, so without this a publisher could park an
# arbitrarily large file of any type in the bucket on our bill.
#
# SVG is deliberately absent from the list: it can carry script, and these
# images render on reader boards where a publication's own markup has no
# business executing.
module ImageAttachable
  extend ActiveSupport::Concern

  CONTENT_TYPES = %w[ image/png image/jpeg image/gif image/webp ].freeze
  MAX_BYTE_SIZE = 5.megabytes
  FORMAT_LIST = "PNG, JPEG, GIF, or WebP"

  class_methods do
    # Validates the named attachment on every save that carries one.
    def validates_attached_image(name)
      validate { validate_attached_image(name) }
    end
  end

  private
    def validate_attached_image(name)
      attachment = public_send(name)
      return unless attachment.attached?

      blob = attachment.blob
      unless blob.content_type.in?(CONTENT_TYPES)
        errors.add(name, "must be a #{FORMAT_LIST} image")
      end
      if blob.byte_size > MAX_BYTE_SIZE
        errors.add(name, "must be smaller than #{MAX_BYTE_SIZE / 1.megabyte}MB")
      end
    end
end
