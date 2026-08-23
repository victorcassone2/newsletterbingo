import { Controller } from "@hotwired/stimulus"

// Filters word chips as you type; no submit, no reload.
export default class extends Controller {
  static targets = [ "chip", "count" ]

  filter(event) {
    const query = event.target.value.trim().toUpperCase()
    let shown = 0
    this.chipTargets.forEach(chip => {
      const match = !query || chip.dataset.label.includes(query)
      chip.hidden = !match
      if (match) shown++
    })
    this.countTarget.textContent = query ? `${shown} of ${this.chipTargets.length} match` : ""
  }
}
