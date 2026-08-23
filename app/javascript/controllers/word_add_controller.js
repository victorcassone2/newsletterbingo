import { Controller } from "@hotwired/stimulus"

// Keeps the quick-add input in flow: after a successful submit the field
// clears and stays focused; idea hints seed the placeholder.
export default class extends Controller {
  static targets = [ "input" ]

  reset(event) {
    if (event.detail.success) this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  hint(event) {
    this.inputTarget.placeholder = event.params.placeholder
    this.inputTarget.focus()
  }
}
