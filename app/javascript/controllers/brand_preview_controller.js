import { Controller } from "@hotwired/stimulus"

// Live-updates the branding preview as color inputs change. Each swatch
// pairs a native picker with a hex text field; either one drives the other.
export default class extends Controller {
  static targets = [ "preview", "logo", "pubname" ]

  update(event) {
    const swatch = event.target
    this.hexFieldFor(swatch).value = swatch.value
    this.paint(swatch)
  }

  updateHex(event) {
    const hex = this.normalizedHex(event.target.value)
    if (!hex) return

    const swatch = this.swatchFor(event.target)
    swatch.value = hex
    this.paint(swatch)
  }

  // Leaving the hex field snaps stray text back to the current color.
  restoreHex(event) {
    event.target.value = this.swatchFor(event.target).value
  }

  // The board shows the logo or the publication name, never both.
  swapLogo(event) {
    const file = event.target.files[0]
    if (!file) return

    if (this.logoTarget.src.startsWith("blob:")) URL.revokeObjectURL(this.logoTarget.src)
    this.logoTarget.src = URL.createObjectURL(file)
    this.logoTarget.hidden = false
    this.pubnameTarget.hidden = true
  }

  paint(swatch) {
    this.previewTarget.style.setProperty(swatch.dataset.brandProperty, swatch.value)
  }

  normalizedHex(value) {
    const match = value.trim().match(/^#?([0-9a-f]{6})$/i)
    return match && `#${match[1].toLowerCase()}`
  }

  swatchFor(hexField) {
    return hexField.closest(".swatch-pair").querySelector("input[type=color]")
  }

  hexFieldFor(swatch) {
    return swatch.closest(".swatch-pair").querySelector(".hex-field")
  }
}
