import { Controller } from "@hotwired/stimulus"

// Typing call content live-updates the footprint previews showing what
// readers see in the email block and on their card after claiming.
export default class extends Controller {
  static targets = [ "descriptionInput", "linkTextInput", "prizeInput", "prizeDescriptionInput",
                     "emailFlag", "storyPrize", "storyDescription", "storyLink", "storyEmpty" ]

  update() {
    const description = this.descriptionInputTarget.value.trim()
    const linkText = this.linkTextInputTarget.value.trim()
    const prize = this.prizeInputTarget.checked
    const prizeDescription = this.prizeDescriptionInputTarget.value.trim()

    this.emailFlagTarget.hidden = !prize
    this.storyPrizeTarget.hidden = !(prize && prizeDescription)
    this.storyPrizeTarget.textContent = `🎁 ${prizeDescription}`
    this.storyDescriptionTarget.hidden = !description
    this.storyDescriptionTarget.textContent = description
    this.storyLinkTarget.hidden = !linkText
    this.storyLinkTarget.textContent = `${linkText} →`
    this.storyEmptyTarget.hidden = Boolean(description || linkText || (prize && prizeDescription))
  }
}
