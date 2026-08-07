# Publisher-entered destination URLs may only be http(s). Anything else
# (javascript:, data:, vbscript:, protocol-relative tricks) is rejected.
class HttpUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    uri = URI.parse(value)
    unless uri.is_a?(URI::HTTP) && uri.host.present?
      record.errors.add(attribute, :invalid, message: "must be a valid http:// or https:// URL")
    end
  rescue URI::InvalidURIError
    record.errors.add(attribute, :invalid, message: "must be a valid http:// or https:// URL")
  end
end
