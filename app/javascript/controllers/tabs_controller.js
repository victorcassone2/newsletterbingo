import { Controller } from "@hotwired/stimulus"

// Segmented panes: one visible at a time, selection mirrored in the URL
// hash so a save can land back on the pane it came from.
export default class extends Controller {
  static targets = [ "tab", "pane" ]

  connect() {
    this.show(window.location.hash.slice(1))
  }

  select(event) {
    const pane = event.currentTarget.dataset.pane
    this.show(pane)
    history.replaceState(null, "", "#" + pane)
  }

  show(name) {
    if (!this.tabTargets.some(tab => tab.dataset.pane === name)) {
      name = this.tabTargets[0].dataset.pane
    }
    this.tabTargets.forEach(tab => tab.classList.toggle("active", tab.dataset.pane === name))
    this.paneTargets.forEach(pane => pane.hidden = pane.dataset.pane !== name)
  }
}
