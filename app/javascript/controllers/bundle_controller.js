import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bundle"
export default class extends Controller {
  static targets = [
    "coursesCatalog", "extrasCatalog", "offerHeader", "progress", "lineItems",
    "subtotal", "discount", "total", "youSave",
    "giftButton", "giftModalOverlay", "giftGrid", "giftRemaining"
  ]

  connect() {
    this.items = []
    this.selectedGifts = []
    this.catalog = []
    this.courses = []
    this.extras = []
    this.config = {}
    this.debouncedPrice = this.debounce(() => this.price(), 200)
    this.loadCatalog()
  }

  async loadCatalog() {
    const res = await fetch('/api/catalog')
    const data = await res.json()
    this.catalog = data.products
    this.config = data.config
    this.courses = this.catalog.filter(p => p.type === 'course' && (p.visible !== false))
    this.extras = this.catalog.filter(p => p.type !== 'course' && (p.visible !== false))
    this.renderCatalog()
    this.updateUi()
  }

  renderCatalog() {
    // Courses
    this.coursesCatalogTarget.innerHTML = ''
    this.courses.forEach(p => {
      const selected = this.items.includes(p.sku)
      const card = document.createElement('div')
      card.className = 'bg-white rounded-xl shadow-sm border border-orange-200 hover:shadow-md transition overflow-hidden'
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
              ${p.type === 'course' ? '<span class="px-2 py-0.5 text-[11px] bg-orange-50 text-orange-700 rounded">Course</span>' : ''}
              ${p.type === 'addon' ? '<span class="px-2 py-0.5 text-[11px] bg-slate-50 text-slate-700 rounded">Add-on</span>' : ''}
              ${p.type === 'gift' ? '<span class="px-2 py-0.5 text-[11px] bg-emerald-50 text-emerald-700 rounded">Gift</span>' : ''}
            </div>
          </div>
          <button class="mt-3 w-full px-3 py-2 rounded text-sm font-medium border ${selected ? 'bg-orange-600 text-white border-orange-600' : 'border-orange-300 text-orange-700 hover:bg-orange-50'}" data-sku="${p.sku}">
            ${selected ? 'Remove' : 'Add to bundle'}
          </button>
        </div>
      `
      card.querySelector('button').addEventListener('click', () => this.toggle(p.sku))
      this.coursesCatalogTarget.appendChild(card)
    })

    // Extras (Downloads & Add-ons & Gifts)
    this.extrasCatalogTarget.innerHTML = ''
    this.extras.forEach(p => {
      const selected = this.items.includes(p.sku)
      const card = document.createElement('div')
      card.className = 'bg-white rounded-xl shadow-sm border border-orange-200 hover:shadow-md transition overflow-hidden'
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
              ${p.type === 'course' ? '<span class="px-2 py-0.5 text-[11px] bg-orange-50 text-orange-700 rounded">Course</span>' : ''}
              ${p.type === 'addon' ? '<span class="px-2 py-0.5 text-[11px] bg-slate-50 text-slate-700 rounded">Add-on</span>' : ''}
              ${p.type === 'gift' ? '<span class="px-2 py-0.5 text-[11px] bg-emerald-50 text-emerald-700 rounded">Gift</span>' : ''}
            </div>
          </div>
          <button class="mt-3 w-full px-3 py-2 rounded text-sm font-medium border ${selected ? 'bg-orange-600 text-white border-orange-600' : 'border-orange-300 text-orange-700 hover:bg-orange-50'}" data-sku="${p.sku}">
            ${selected ? 'Remove' : 'Add to bundle'}
          </button>
        </div>
      `
      card.querySelector('button').addEventListener('click', () => this.toggle(p.sku))
      this.extrasCatalogTarget.appendChild(card)
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

    if (courseCount === 0) {
      this.progressTarget.textContent = 'No courses added — add 2 to unlock discounts + gifts.'
    } else {
      const courseLabel = courseCount === 1 ? 'Course' : 'Courses'
      const giftLabel = giftAllowed === 1 ? 'free gift' : 'free gifts'
      this.progressTarget.textContent = `${courseCount} ${courseLabel} selected: ${percent}% off + ${giftAllowed} ${giftLabel}`
    }

    // Line items
    this.lineItemsTarget.innerHTML = ''
    if (r) {
      let addedGiftHeader = false
      r.items.forEach(li => {
        const liEl = document.createElement('li')
        const isGift = !!li.isGift
        liEl.className = `py-2 flex items-center justify-between gap-2 ${isGift ? 'bg-emerald-50/60' : ''}`
        const price = li.isGift ? '$0.00' : `$${li.net.toFixed(2)}`
        const msrp = li.discount > 0 ? `<span class="line-through text-gray-400 mr-1">$${li.msrp.toFixed(2)}</span>` : ''
        const disc = li.discount > 0 ? `<span class="text-orange-700 mr-1">- $${li.discount.toFixed(2)}</span>` : ''
        liEl.innerHTML = `
          <div>
            <div class="text-sm ${isGift ? 'text-emerald-800' : ''}">${li.title}</div>
            <div class="text-xs ${isGift ? 'text-emerald-700' : 'text-gray-500'}">${li.badges.join(', ')}</div>
          </div>
          <div class="text-sm ${isGift ? 'text-emerald-800' : ''}">${msrp}${disc}<strong>${price}</strong></div>
        `
        if (isGift && !addedGiftHeader) {
          const header = document.createElement('li')
          header.className = 'pt-3 pb-1 text-xs font-semibold text-emerald-800'
          header.textContent = 'Gifts'
          this.lineItemsTarget.appendChild(header)
          addedGiftHeader = true
        }
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
      el.className = `border rounded p-2 text-left ${selected ? 'ring-2 ring-orange-500' : ''}`
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
    // Post payload to server to render review page, not Stripe
    const res = await fetch('/checkout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ payload: this.result })
    })
    if (res.ok) window.location.href = '/checkout'
    else alert('Unable to proceed to checkout')
  }

  debounce(fn, delay) {
    let t
    return (...args) => {
      clearTimeout(t)
      t = setTimeout(() => fn.apply(this, args), delay)
    }
  }
}


