import { Controller } from "@hotwired/stimulus"

// Copies the content of a source element (input, textarea, or text) and
// gives brief button feedback.
export default class extends Controller {
  static targets = [ "source", "button" ]

  copy() {
    const source = this.sourceTarget
    const text = "value" in source && source.value !== undefined && source.tagName !== "DIV"
      ? source.value
      : source.textContent
    navigator.clipboard.writeText(text.trim()).then(() => this.flash())
  }

  flash() {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied ✓"
    setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
