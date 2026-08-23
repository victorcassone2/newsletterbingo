import { Controller } from "@hotwired/stimulus"

// Typing a sponsor name live-updates the footprint previews showing
// where it appears to readers.
export default class extends Controller {
  static targets = [ "name" ]

  update(event) {
    const name = event.target.value.trim() || "—"
    this.nameTargets.forEach(target => target.textContent = name)
  }
}
