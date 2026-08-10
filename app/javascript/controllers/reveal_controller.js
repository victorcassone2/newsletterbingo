import { Controller } from "@hotwired/stimulus"

// Unhides collapsed list items and removes the trigger row.
export default class extends Controller {
  static targets = [ "item", "trigger" ]

  show() {
    this.itemTargets.forEach(item => item.hidden = false)
    this.triggerTarget.remove()
  }
}
