import { Controller } from "@hotwired/stimulus"

// Small disclosure menu (the account dropdown in the top bar): toggles the
// panel's hidden attribute and closes on any click outside.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.panelTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.hidden = false
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.panelTarget.hidden = true
    document.removeEventListener("click", this.boundClose)
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }
}
