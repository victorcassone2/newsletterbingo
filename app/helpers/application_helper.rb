module ApplicationHelper
  # Black or white, whichever reads better on the given hex background.
  def contrast_text_color(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) }
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    luminance > 0.6 ? "#111111" : "#ffffff"
  end

  # CSS custom properties carrying a publication's branding.
  def brand_style(publication)
    [
      "--brand-primary: #{publication.primary_color}",
      "--brand-accent: #{publication.accent_color}",
      "--brand-background: #{publication.background_color}",
      "--brand-text: #{publication.text_color}",
      "--brand-on-accent: #{contrast_text_color(publication.accent_color)}",
      "--brand-on-primary: #{contrast_text_color(publication.primary_color)}"
    ].join("; ")
  end

  def nav_link_to(name, path, active:)
    link_to name, path, class: class_names("nav-link", active: active)
  end

  def timezone_options
    ActiveSupport::TimeZone.all.map { |zone| [ zone.to_s, zone.tzinfo.identifier ] }.uniq(&:last)
  end
end
