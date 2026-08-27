import { Controller } from "@hotwired/stimulus"

// Platform chips prefill the merge tags, so publishers never transcribe
// tag syntax from their platform's docs. A chip for a platform with no
// campaign id carries an empty data-campaign, which clears the field:
// blank is what tells us to infer sends instead of proving them.
export default class extends Controller {
  static targets = [ "chip", "emailTag", "campaignTag", "hint" ]

  choose(event) {
    const chip = event.currentTarget
    this.chipTargets.forEach(other => other.classList.toggle("active", other === chip))
    this.hintTarget.textContent = chip.dataset.hint

    if (chip.dataset.email) this.emailTagTarget.value = chip.dataset.email
    if ("campaign" in chip.dataset) this.campaignTagTarget.value = chip.dataset.campaign
  }
}
