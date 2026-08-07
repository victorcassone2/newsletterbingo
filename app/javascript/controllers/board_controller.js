import { Controller } from "@hotwired/stimulus"

// Tapping a claimed square reveals its detail card under the board.
export default class extends Controller {
  static targets = [ "detail" ]

  reveal(event) {
    const key = event.currentTarget.dataset.squareKey
    let shown = false
    this.detailTargets.forEach(detail => {
      const matches = detail.dataset.squareKey === key
      const show = matches && detail.hidden
      detail.hidden = !show
      if (show) shown = detail
    })
    if (shown) shown.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }
}
