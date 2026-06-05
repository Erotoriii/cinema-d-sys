import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  openCreateDialog(event) {
    event?.preventDefault()

    if (this.hasDialogTarget && !this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
  }

  closeCreateDialog(event) {
    event?.preventDefault()

    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  changeQuantity(event) {
    event.preventDefault()

    const button = event.currentTarget
    const row = button.closest("[data-product-row]")
    const fieldType = button.dataset.adjustTarget
    const direction = button.dataset.direction
    const input = row.querySelector(`.${fieldType}-qty`)
    const currentValue = Number.parseInt(input.value || "0", 10)
    const step = direction === "plus" ? 1 : -1

    if (fieldType === "sold") {
      const nextValue = Math.max(0, Math.min(currentValue + step, this.maxSellableUnits(row)))
      input.value = nextValue
      return
    }

    const nextValue = Math.max(0, currentValue + step)
    if (this.availableUnitsAfterArrival(row, nextValue) < this.soldValue(row)) {
      return
    }

    input.value = nextValue
  }

  soldValue(row) {
    return Number.parseInt(row.querySelector(".sold-qty").value || "0", 10)
  }

  arrivedValue(row) {
    return Number.parseInt(row.querySelector(".arrived-qty").value || "0", 10)
  }

  initialAmount(row) {
    return Number.parseInt(row.dataset.initialAmount || "0", 10)
  }

  maxSellableUnits(row) {
    return this.initialAmount(row) + this.arrivedValue(row)
  }

  availableUnitsAfterArrival(row, arrivedAmount) {
    return this.initialAmount(row) + arrivedAmount
  }
}