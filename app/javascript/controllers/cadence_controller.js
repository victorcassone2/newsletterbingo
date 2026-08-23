import { Controller } from "@hotwired/stimulus"

// Each cadence choice carries its own follow-up settings: selecting one
// reveals its panel and hides the others, without a save round-trip.
export default class extends Controller {
  static targets = [ "choice", "panel" ]

  connect() {
    this.update()
  }

  update() {
    const selected = this.choiceTargets.find(choice => choice.checked)?.value
    this.panelTargets.forEach(panel => panel.hidden = panel.dataset.cadence !== selected)
  }
}
