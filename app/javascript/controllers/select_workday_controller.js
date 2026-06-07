import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "form"]

  connect() {
    // Show modal immediately when controller connects
    if (this.hasDialogTarget) {
      try {
        this.dialogTarget.showModal()
      } catch (e) {
        // fallback for browsers without <dialog> support
        this.dialogTarget.style.display = 'block'
      }
    }
  }

  async submit(event) {
    event.preventDefault()
    const form = this.hasFormTarget ? this.formTarget : event.target
    const url = form.action
    const formData = new FormData(form)

    // include CSRF token header
    const token = document.querySelector('meta[name=csrf-token]')?.content || ''

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'X-CSRF-Token': token, 'Accept': 'application/json' },
      body: formData,
      credentials: 'same-origin'
    })

    if (response.ok) {
      // close dialog and reload to reflect active shift
      try { this.dialogTarget.close() } catch(e) { this.dialogTarget.style.display='none' }
      window.location.reload()
    } else {
      const text = await response.text()
      alert('Не вдалося розпочати зміну.')
      console.error('Workday start error', text)
    }
  }
}
