import { Controller } from "@hotwired/stimulus"

// Platform chips prefill the merge tags and pick the cadence that fits,
// so publishers never transcribe tag syntax from their platform's docs.
export default class extends Controller {
  static targets = [ "chip", "emailTag", "campaignTag", "hint" ]

  choose(event) {
    const chip = event.currentTarget
    this.chipTargets.forEach(other => other.classList.toggle("active", other === chip))
    this.hintTarget.textContent = chip.dataset.hint

    if (chip.dataset.email) this.emailTagTarget.value = chip.dataset.email
    if (chip.dataset.campaign) this.campaignTagTarget.value = chip.dataset.campaign
    if (chip.dataset.cadence) this.setCadence(chip.dataset.cadence)
  }

  setCadence(value) {
    const radio = this.element.querySelector(`input[name="publication[cadence]"][value="${value}"]`)
    if (!radio || radio.checked) return
    radio.checked = true
    radio.dispatchEvent(new Event("input", { bubbles: true }))
    radio.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
