import { Controller } from "@hotwired/stimulus"

// Tapping a claimed square opens its detail card inside the square's own
// row; the open square keeps an accent outline. One card open at a time.
export default class extends Controller {
  static targets = [ "square", "detail" ]

  reveal(event) {
    const button = event.currentTarget
    const key = button.dataset.squareKey
    const detail = this.detailTargets.find(d => d.dataset.squareKey === key)
    const opening = detail.hidden

    this.detailTargets.forEach(d => d.hidden = true)
    this.squareTargets.forEach(s => {
      s.classList.remove("open-sq")
      s.setAttribute("aria-expanded", "false")
    })

    if (opening) {
      detail.hidden = false
      button.classList.add("open-sq")
      button.setAttribute("aria-expanded", "true")
    }
  }
}
