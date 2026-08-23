module ApplicationHelper
  # Black or white, whichever has the higher WCAG contrast ratio on the
  # given hex background. The better of the two always clears AA (4.5:1).
  def contrast_text_color(hex)
    contrast_ratio(hex, "#000000") > contrast_ratio(hex, "#ffffff") ? "#111111" : "#ffffff"
  end

  # CSS custom properties carrying a publication's branding. Cards render
  # on --brand-surface, computed so they stay readable whether the
  # publisher picked a light or a dark background.
  def brand_style(publication)
    surface = brand_surface_color(publication.background_color)
    [
      "--brand-primary: #{publication.primary_color}",
      "--brand-accent: #{publication.accent_color}",
      "--brand-background: #{publication.background_color}",
      "--brand-text: #{publication.text_color}",
      "--brand-on-accent: #{contrast_text_color(publication.accent_color)}",
      "--brand-on-primary: #{contrast_text_color(publication.primary_color)}",
      "--brand-surface: #{surface}",
      "--brand-on-surface: #{brand_on_surface_color(publication.text_color, surface)}"
    ].join("; ")
  end

  def nav_link_to(name, path, active:)
    link_to name, path, class: class_names("nav-link", active: active)
  end

  def timezone_options
    ActiveSupport::TimeZone.all.map { |zone| [ zone.to_s, zone.tzinfo.identifier ] }.uniq(&:last)
  end

  # Inline SVG sparkline of recent per-word claim counts for the Today
  # pulse. All coordinates are computed numbers, so the markup is safe.
  def claim_sparkline(counts, width: 150, height: 36)
    return "".html_safe if counts.size < 2

    max = [ counts.max, 1 ].max
    step = (width - 10.0) / (counts.size - 1)
    points = counts.each_with_index.map do |count, index|
      [ (5 + index * step).round(1), (height - 3 - (count.to_f / max) * (height - 10)).round(1) ]
    end
    line = points.each_with_index.map { |(x, y), i| "#{i.zero? ? "M" : "L"}#{x} #{y}" }.join(" ")
    area = "#{line} L#{points.last[0]} #{height - 1} L#{points.first[0]} #{height - 1} Z"
    <<~SVG.html_safe
      <svg width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" role="img" aria-label="Claims per word, recent words">
        <line x1="0" y1="#{height - 1}" x2="#{width}" y2="#{height - 1}" stroke="#e2e8f0" stroke-width="1"/>
        <path d="#{area}" fill="#059669" fill-opacity="0.12"/>
        <path d="#{line}" fill="none" stroke="#059669" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        <circle cx="#{points.last[0]}" cy="#{points.last[1]}" r="3.5" fill="#059669" stroke="#ffffff" stroke-width="1.5"/>
      </svg>
    SVG
  end

  private
    # White cards on light backgrounds; on dark backgrounds, a slightly
    # lifted shade of the background itself.
    def brand_surface_color(background)
      if relative_luminance(background) > 0.35
        "#ffffff"
      else
        mix_hex(background, "#ffffff", 0.12)
      end
    end

    # The publisher's text color when it reads on the surface, otherwise
    # plain black/white.
    def brand_on_surface_color(text, surface)
      if contrast_ratio(text, surface) >= 4.5
        text
      else
        contrast_text_color(surface)
      end
    end

    def contrast_ratio(hex_a, hex_b)
      light, dark = [ relative_luminance(hex_a), relative_luminance(hex_b) ].sort.reverse
      (light + 0.05) / (dark + 0.05)
    end

    def relative_luminance(hex)
      linear = hex.delete("#").scan(/../).map do |channel|
        srgb = channel.to_i(16) / 255.0
        srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055)**2.4
      end
      0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    end

    def mix_hex(hex, other, weight)
      base = hex.delete("#").scan(/../).map { |channel| channel.to_i(16) }
      target = other.delete("#").scan(/../).map { |channel| channel.to_i(16) }
      blended = base.zip(target).map { |a, b| (a * (1 - weight) + b * weight).round }
      format("#%02x%02x%02x", *blended)
    end
end
