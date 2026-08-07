import { Controller } from "@hotwired/stimulus"

// Live-updates the branding preview as color inputs change.
export default class extends Controller {
  static targets = [ "preview" ]

  update(event) {
    const property = event.target.dataset.brandProperty
    if (property) this.previewTarget.style.setProperty(property, event.target.value)
  }
}
