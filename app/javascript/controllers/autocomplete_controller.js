import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "latitude", "longitude", "map", "mapContainer"]
  static values = { minLength: { type: Number, default: 3 } }

  connect() {
    this.timeout = null
    this.leafletMap = null
    this.marker = null
    this.hideResults()
    // Prevent Enter key from submitting the form
    this.inputTarget.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      // If location is set, show map
      if (this.latitudeTarget.value && this.longitudeTarget.value) {
        this.showMapPreview()
      }
      this.hideResults()
    }
  }

  showMapPreview() {
    const lat = parseFloat(this.latitudeTarget.value)
    const lon = parseFloat(this.longitudeTarget.value)

    if (isNaN(lat) || isNaN(lon)) return

    // Show the map container
    if (this.hasMapContainerTarget) {
      this.mapContainerTarget.classList.remove('hidden')
    }

    // Initialize or update map
    if (!this.leafletMap && this.hasMapTarget && typeof L !== 'undefined') {
      this.leafletMap = L.map(this.mapTarget, {
        zoomControl: false,
        attributionControl: false
      }).setView([lat, lon], 12)

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(this.leafletMap)

      this.marker = L.marker([lat, lon]).addTo(this.leafletMap)
    } else if (this.leafletMap) {
      this.leafletMap.setView([lat, lon], 12)
      if (this.marker) {
        this.marker.setLatLng([lat, lon])
      }
    }
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
              class="w-full text-left px-4 py-3 transition-colors"
              style="border-bottom: 1px solid #7D6D5D; color: #F5D67A;"
              onmouseover="this.style.backgroundColor='#4A3F2F'"
              onmouseout="this.style.backgroundColor='transparent'"
              data-action="click->autocomplete#select"
              data-lat="${result.lat}"
              data-lon="${result.lon}"
              data-name="${result.display_name}">
        <span class="text-sm line-clamp-2">${result.display_name}</span>
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

    // Show map preview
    this.showMapPreview()
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
