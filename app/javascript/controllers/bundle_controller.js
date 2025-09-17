import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bundle"
export default class extends Controller {
  static targets = [
    "catalog", "offerHeader", "progress", "lineItems",
    "subtotal", "discount", "total", "youSave",
    "giftButton", "giftModalOverlay", "giftGrid", "giftRemaining"
  ]

  connect() {
    this.items = []
    this.selectedGifts = []
    this.catalog = []
    this.config = {}
    this.debouncedPrice = this.debounce(() => this.price(), 200)
    this.loadCatalog()
  }

  async loadCatalog() {
    const res = await fetch('/api/catalog')
    const data = await res.json()
    this.catalog = data.products
    this.config = data.config
    this.renderCatalog()
    this.updateUi()
  }

  renderCatalog() {
    this.catalogTarget.innerHTML = ''
    this.catalog.forEach(p => {
      const selected = this.items.includes(p.sku)
      const card = document.createElement('div')
      card.className = 'bg-white rounded-xl shadow-sm border border-blue-200 hover:shadow-md transition overflow-hidden'
      card.innerHTML = `
        <div class="aspect-[4/3] bg-gray-100 overflow-hidden">
          <img src="${p.imageUrl}" alt="${p.title}" class="w-full h-full object-cover" loading="lazy" />
        </div>
        <div class="p-3">
          <div class="font-semibold leading-snug">${p.title}</div>
          <div class="text-sm text-gray-600 line-clamp-2">${p.summary || ''}</div>
          <div class="mt-2 flex items-center justify-between">
            <div class="text-sm font-medium">$${p.msrp.toFixed(2)}</div>
            <div class="flex gap-1">
              ${p.type === 'course' ? '<span class="px-2 py-0.5 text-[11px] bg-blue-50 text-blue-700 rounded">Course</span>' : ''}
              ${p.type === 'addon' ? '<span class="px-2 py-0.5 text-[11px] bg-slate-50 text-slate-700 rounded">Add-on</span>' : ''}
              ${p.type === 'gift' ? '<span class="px-2 py-0.5 text-[11px] bg-emerald-50 text-emerald-700 rounded">Gift</span>' : ''}
            </div>
          </div>
          <button class="mt-3 w-full px-3 py-2 rounded text-sm font-medium border ${selected ? 'bg-blue-600 text-white border-blue-600' : 'border-blue-300 text-blue-700 hover:bg-blue-50'}" data-sku="${p.sku}">
            ${selected ? 'Remove' : 'Add to bundle'}
          </button>
        </div>
      `
      card.querySelector('button').addEventListener('click', () => this.toggle(p.sku))
      this.catalogTarget.appendChild(card)
    })
  }

  toggle(sku) {
    const idx = this.items.indexOf(sku)
    if (idx >= 0) this.items.splice(idx, 1)
    else this.items.push(sku)
    this.renderCatalog()
    this.debouncedPrice()
  }

  async price() {
    const res = await fetch('/api/cart/price', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: this.items, selectedGifts: this.selectedGifts })
    })
    this.result = await res.json()
    this.updateUi()
  }

  updateUi() {
    const r = this.result
    const courseCount = r ? r.course_count : 0
    const percent = r ? r.percent_off : 0
    const giftAllowed = r ? r.gift_count_allowed : 0
    const scope = r ? r.scope : 'courses_only'

    // Offer header & progress
    this.offerHeaderTarget.textContent = courseCount >= 3
      ? `Add 3 courses → save ${percent}% on ${scope === 'entire_cart' ? 'entire cart' : 'courses'} + ${giftAllowed} gifts.`
      : courseCount >= 2
        ? `Add 2 courses → save ${percent}% + ${giftAllowed} gift.`
        : `Choose 2–3 courses to unlock big savings and free gifts.`

    this.progressTarget.textContent = courseCount === 0
      ? 'No courses added — add 2 to unlock discounts + gifts.'
      : courseCount === 1
        ? '1 course added — add 1 more for Tier 1 benefits.'
        : `${courseCount} courses added.`

    // Line items
    this.lineItemsTarget.innerHTML = ''
    if (r) {
      r.items.forEach(li => {
        const liEl = document.createElement('li')
        liEl.className = 'py-2 flex items-center justify-between gap-2'
        const price = li.isGift ? '$0.00' : `$${li.net.toFixed(2)}`
        const msrp = li.discount > 0 ? `<span class="line-through text-gray-400 mr-1">$${li.msrp.toFixed(2)}</span>` : ''
        const disc = li.discount > 0 ? `<span class="text-blue-700 mr-1">- $${li.discount.toFixed(2)}</span>` : ''
        liEl.innerHTML = `
          <div>
            <div class="text-sm">${li.title}</div>
            <div class="text-xs text-gray-500">${li.badges.join(', ')}</div>
          </div>
          <div class="text-sm">${msrp}${disc}<strong>${price}</strong></div>
        `
        this.lineItemsTarget.appendChild(liEl)
      })
      const subtotal = r.totals.subtotal || 0
      const discount = r.totals.discount || 0
      const total = r.totals.total || 0
      const percentSave = subtotal > 0 ? Math.round((discount / subtotal) * 100) : 0
      this.subtotalTarget.textContent = `$${subtotal.toFixed(2)}`
      this.discountTarget.textContent = `-$${discount.toFixed(2)}`
      this.totalTarget.textContent = `$${total.toFixed(2)}`
      this.youSaveTarget.textContent = `$${discount.toFixed(2)} (${percentSave}%)`
    }

    // Actions
    const canCheckout = this.items.length > 0
    this.element.querySelector('[data-action="bundle#proceed"]').disabled = !canCheckout
    this.giftButtonTarget.disabled = !(r && r.gift_count_allowed > 0)
  }

  openGifts = async () => {
    const r = this.result
    if (!r) return
    const pool = r.gift_pool_skus
    const allowed = r.gift_count_allowed
    const remaining = allowed - this.selectedGifts.length
    this.giftRemainingTarget.textContent = remaining
    this.giftGridTarget.innerHTML = ''
    pool.forEach(sku => {
      const p = this.catalog.find(x => x.sku === sku)
      if (!p) return
      const selected = this.selectedGifts.includes(sku)
      const el = document.createElement('button')
      el.className = `border rounded p-2 text-left ${selected ? 'ring-2 ring-blue-500' : ''}`
      el.innerHTML = `
        <img src="${p.imageUrl}" alt="" class="w-full h-24 object-cover rounded" />
        <div class="mt-2 text-sm">${p.title}</div>
        <div class="text-xs text-gray-500">$${p.msrp.toFixed(2)}</div>
      `
      el.addEventListener('click', () => this.toggleGift(sku))
      this.giftGridTarget.appendChild(el)
    })
    this.giftModalOverlayTarget.classList.remove('hidden')
    this.giftModalOverlayTarget.setAttribute('aria-hidden', 'false')
  }

  closeGifts = () => {
    this.giftModalOverlayTarget.classList.add('hidden')
    this.giftModalOverlayTarget.setAttribute('aria-hidden', 'true')
  }

  toggleGift(sku) {
    const r = this.result
    if (!r) return
    const allowed = r.gift_count_allowed
    const idx = this.selectedGifts.indexOf(sku)
    if (idx >= 0) this.selectedGifts.splice(idx, 1)
    else if (this.selectedGifts.length < allowed) this.selectedGifts.push(sku)
    this.price()
    this.openGifts()
  }

  proceed = async () => {
    if (!this.result) return
    const payload = this.result
    const res = await fetch('/api/checkout/session', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ payload })
    })
    const data = await res.json()
    if (data.redirectUrl) {
      window.location.href = data.redirectUrl
    } else if (data.error) {
      alert(data.error)
    }
  }

  debounce(fn, delay) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn.apply(this, args), delay)
    }
  }
}


