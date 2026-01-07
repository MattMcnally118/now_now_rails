import { Controller } from "@hotwired/stimulus"
import * as L from "leaflet"

export default class extends Controller {
  static values = {
    dataUrl: String,
    mode: { type: String, default: "markers" }
  }

  static targets = ["container"]

  // Animal color palette (matches original Python app)
  palette = {
    "Cheetah": "#e41a1c",
    "Elephant": "#377eb8",
    "Giraffe": "#4daf4a",
    "Hippopotamus": "#984ea3",
    "Lion": "#ff7f00",
    "Warthog": "#a65628",
    "Zebra": "#f781bf"
  }

  connect() {
    this.initMap()
    this.loadData()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }

  initMap() {
    // Center on South Africa
    this.map = L.map(this.containerTarget).setView([-25.5, 28.5], 6)

    // Add tile layer (CartoDB light tiles like original app)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; OpenStreetMap, &copy; CARTO',
      subdomains: 'abcd',
      maxZoom: 19
    }).addTo(this.map)

    // Store layers for mode switching
    this.markersLayer = null
    this.heatLayer = null
  }

  async loadData() {
    try {
      const response = await fetch(this.dataUrlValue)
      this.sightings = await response.json()
      this.renderMode(this.modeValue)
    } catch (error) {
      console.error("Failed to load sightings:", error)
    }
  }

  renderMode(mode) {
    // Clear existing layers
    this.clearLayers()

    switch(mode) {
      case "heatmap":
        this.renderHeatmap()
        break
      case "clustered":
        this.renderClustered()
        break
      case "markers":
      default:
        this.renderMarkers()
    }
  }

  clearLayers() {
    if (this.markersLayer) {
      this.map.removeLayer(this.markersLayer)
      this.markersLayer = null
    }
  }

  renderMarkers() {
    this.markersLayer = L.layerGroup()

    this.sightings.forEach(s => {
      const color = this.palette[s.animal] || "#377eb8"

      const marker = L.circleMarker([s.lat, s.lon], {
        radius: 6,
        color: color,
        fillColor: color,
        fillOpacity: 0.7,
        weight: 1
      })

      marker.bindPopup(`
        <div class="text-sm">
          <strong>${s.animal}</strong><br>
          <span class="text-gray-600">${s.species || ''}</span><br>
          <hr class="my-1">
          <strong>Date:</strong> ${s.datetime ? new Date(s.datetime).toLocaleDateString() : 'N/A'}<br>
          <strong>NDVI:</strong> ${s.ndvi || 'N/A'}<br>
          <strong>Temp:</strong> ${s.temp ? s.temp + '°C' : 'N/A'}<br>
          <strong>Water:</strong> ${s.dist_water ? s.dist_water + ' km' : 'N/A'}
        </div>
      `)

      this.markersLayer.addLayer(marker)
    })

    this.markersLayer.addTo(this.map)
  }

  renderClustered() {
    // Simple clustering by proximity - group nearby markers
    this.markersLayer = L.layerGroup()

    // For simplicity, just render all markers with smaller radius
    this.sightings.forEach(s => {
      const color = this.palette[s.animal] || "#377eb8"

      const marker = L.circleMarker([s.lat, s.lon], {
        radius: 4,
        color: color,
        fillColor: color,
        fillOpacity: 0.5,
        weight: 0.5
      })

      this.markersLayer.addLayer(marker)
    })

    this.markersLayer.addTo(this.map)
  }

  renderHeatmap() {
    // Simple heatmap using semi-transparent circles
    this.markersLayer = L.layerGroup()

    this.sightings.forEach(s => {
      const marker = L.circleMarker([s.lat, s.lon], {
        radius: 10,
        color: 'transparent',
        fillColor: '#ff5722',
        fillOpacity: 0.15,
        weight: 0
      })

      this.markersLayer.addLayer(marker)
    })

    this.markersLayer.addTo(this.map)
  }

  // Called from Turbo when mode changes
  switchMode(event) {
    const mode = event.currentTarget.dataset.mode
    this.modeValue = mode
    this.renderMode(mode)

    // Update active button styles
    document.querySelectorAll('[data-mode]').forEach(btn => {
      btn.classList.remove('bg-amber-500', 'text-white')
      btn.classList.add('bg-white', 'text-amber-800')
    })
    event.currentTarget.classList.remove('bg-white', 'text-amber-800')
    event.currentTarget.classList.add('bg-amber-500', 'text-white')
  }
}
