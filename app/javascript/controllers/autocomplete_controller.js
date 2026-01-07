import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "latitude", "longitude"]
  static values = { minLength: { type: Number, default: 3 } }

  connect() {
    this.timeout = null
    this.hideResults()
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.fetchSuggestions(query)
    }, 300)
  }

  async fetchSuggestions(query) {
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5`
      const response = await fetch(url, {
        headers: { 'User-Agent': 'NowNowWildlifeFinder/1.0' }
      })
      const data = await response.json()
      this.displayResults(data)
    } catch (error) {
      console.error('Geocoding error:', error)
      this.hideResults()
    }
  }

  displayResults(results) {
    if (results.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = results.map(result => `
      <button type="button"
              class="w-full text-left px-4 py-3 hover:bg-amber-50 border-b border-gray-100 last:border-0 transition-colors"
              data-action="click->autocomplete#select"
              data-lat="${result.lat}"
              data-lon="${result.lon}"
              data-name="${result.display_name}">
        <span class="text-sm text-gray-800 line-clamp-2">${result.display_name}</span>
      </button>
    `).join('')

    this.resultsTarget.classList.remove('hidden')
  }

  select(event) {
    const { lat, lon, name } = event.currentTarget.dataset
    this.inputTarget.value = name
    this.latitudeTarget.value = lat
    this.longitudeTarget.value = lon
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
    this.resultsTarget.innerHTML = ''
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }
}
