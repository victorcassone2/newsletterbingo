import { Controller } from "@hotwired/stimulus"

// Drag-and-drop reordering for word lists. Dropping applies the move to
// the DOM immediately and PATCHes the dragged row's position resource in
// the background; a rejected move reloads to resync with the server.
//
// Modes mirror the server's semantics:
// * "rows"  (draft reveal order) — the whole row moves and slots renumber.
// * "words" (live schedule) — word labels rotate among fixed slots, which
//   keep their dates, sponsors, and prize badges.
export default class extends Controller {
  dragstart(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
  }

  dragover(event) {
    if (!this.dragged) return
    event.preventDefault()
    event.currentTarget.classList.add("drag-over")
  }

  dragleave(event) {
    event.currentTarget.classList.remove("drag-over")
  }

  drop(event) {
    event.preventDefault()
    const target = event.currentTarget
    target.classList.remove("drag-over")
    if (!this.dragged || this.dragged === target) return

    const url = this.dragged.dataset.sortableUrl
    const to = target.dataset.sortablePosition
    if (this.element.dataset.sortableMode === "rows") {
      this.moveRow(this.dragged, target)
    } else {
      this.rotateWords(this.dragged, target)
    }
    this.patchPosition(url, to)
  }

  dragend() {
    this.dragged = null
    this.element.querySelectorAll(".drag-over").forEach(row => row.classList.remove("drag-over"))
  }

  moveRow(dragged, target) {
    const rows = this.draggableRows()
    if (rows.indexOf(dragged) < rows.indexOf(target)) {
      target.after(dragged)
    } else {
      target.before(dragged)
    }
    this.draggableRows().forEach((row, index) => {
      row.dataset.sortablePosition = index + 1
      row.querySelector(".day-no").textContent = `Word ${index + 1}`
    })
  }

  rotateWords(dragged, target) {
    const rows = this.draggableRows()
    const from = rows.indexOf(dragged)
    const to = rows.indexOf(target)
    const affected = rows.slice(Math.min(from, to), Math.max(from, to) + 1)
    const labels = affected.map(row => row.querySelector(".word").textContent)
    const rotated = from < to
      ? [ ...labels.slice(1), labels[0] ]
      : [ labels[labels.length - 1], ...labels.slice(0, -1) ]
    affected.forEach((row, index) => row.querySelector(".word").textContent = rotated[index])
  }

  patchPosition(url, to) {
    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({ to: to })
    }).then(response => {
      if (!response.ok) this.resync()
    }).catch(() => this.resync())
  }

  resync() {
    Turbo.visit(window.location.href, { action: "replace" })
  }

  draggableRows() {
    return Array.from(this.element.querySelectorAll("li[draggable='true']"))
  }
}
