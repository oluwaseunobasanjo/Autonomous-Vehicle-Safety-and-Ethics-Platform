;; Traffic Optimization Coordination Contract
;; Coordinates autonomous vehicles to reduce congestion and emissions

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-INPUT (err u301))
(define-constant ERR-ROUTE-NOT-FOUND (err u302))
(define-constant ERR-VEHICLE-NOT-REGISTERED (err u303))
(define-constant ERR-CONGESTION-LIMIT-REACHED (err u304))
(define-constant ERR-OPTIMIZATION-FAILED (err u305))

;; Data Variables
(define-data-var next-route-id uint u1)
(define-data-var next-zone-id uint u1)
(define-data-var global-optimization-active bool true)
(define-data-var total-emissions-saved uint u0)

;; Data Maps
(define-map traffic-zones
  { zone-id: uint }
  {
    zone-name: (string-ascii 50),
    coordinates: {
      north-lat: (string-ascii 20),
      south-lat: (string-ascii 20),
      east-lng: (string-ascii 20),
      west-lng: (string-ascii 20)
    },
    current-congestion: uint, ;; 0-100 scale
    max-capacity: uint,
    current-vehicles: uint,
    average-speed: uint,
    emission-factor: uint,
    priority-level: uint, ;; 1-5, 5 being highest priority
    last-updated: uint
  }
)

(define-map route-requests
  { route-id: uint }
  {
    vehicle-id: uint,
    origin: (string-ascii 50),
    destination: (string-ascii 50),
    departure-time: uint,
    arrival-deadline: uint,
    priority-level: uint, ;; 1-5 scale
    passenger-count: uint,
    vehicle-type: (string-ascii 30), ;; "personal", "commercial", "emergency"
    fuel-efficiency: uint,
    status: (string-ascii 20), ;; "pending", "optimized", "active", "completed"
    assigned-route: (string-ascii 500),
    estimated-emissions: uint,
    actual-emissions: uint
  }
)

(define-map optimized-routes
  { route-id: uint, segment-id: uint }
  {
    zone-id: uint,
    entry-time: uint,
    exit-time: uint,
    speed-limit: uint,
    congestion-factor: uint,
    alternative-available: bool,
    emissions-estimate: uint
  }
)

(define-map vehicle-performance
  { vehicle-id: uint }
  {
    total-routes: uint,
    total-distance: uint,
    total-emissions: uint,
    average-efficiency: uint,
    congestion-contribution: uint,
    optimization-compliance: uint, ;; Percentage of following optimized routes
    last-route-time: uint,
    performance-score: uint
  }
)

(define-map coordination-incentives
  { vehicle-id: uint, period: uint }
  {
    emissions-saved: uint,
    congestion-reduced: uint,
    route-efficiency: uint,
    cooperation-score: uint,
    reward-earned: uint,
    penalty-applied: uint
  }
)

(define-map real-time-conditions
  { zone-id: uint, timestamp: uint }
  {
    traffic-density: uint,
    average-speed: uint,
    incident-count: uint,
    weather-impact: uint,
    construction-impact: uint,
    event-impact: uint
  }
)

;; Initialize default traffic zones
(map-set traffic-zones { zone-id: u1 }
  {
    zone-name: "downtown-core",
    coordinates: { north-lat: "37.7849", south-lat: "37.7749", east-lng: "-122.4094", west-lng: "-122.4194" },
    current-congestion: u45,
    max-capacity: u1000,
    current-vehicles: u450,
    average-speed: u25,
    emission-factor: u15,
    priority-level: u5,
    last-updated: u0
  })

(map-set traffic-zones { zone-id: u2 }
  {
    zone-name: "residential-north",
    coordinates: { north-lat: "37.7949", south-lat: "37.7849", east-lng: "-122.4094", west-lng: "-122.4194" },
    current-congestion: u20,
    max-capacity: u500,
    current-vehicles: u100,
    average-speed: u35,
    emission-factor: u8,
    priority-level: u2,
    last-updated: u0
  })

;; Public Functions

;; Register a route optimization request
(define-public (request-route-optimization
  (vehicle-id uint)
  (origin (string-ascii 50))
  (destination (string-ascii 50))
  (departure-time uint)
  (arrival-deadline uint)
  (priority-level uint)
  (passenger-count uint)
  (vehicle-type (string-ascii 30))
  (fuel-efficiency uint)
)
  (let (
    (route-id (var-get next-route-id))
  )
    ;; Validate input
    (asserts! (var-get global-optimization-active) ERR-NOT-AUTHORIZED)
    (asserts! (<= priority-level u5) ERR-INVALID-INPUT)
    (asserts! (> arrival-deadline departure-time) ERR-INVALID-INPUT)
    (asserts! (> fuel-efficiency u0) ERR-INVALID-INPUT)

    ;; Check if vehicle is registered
    (asserts! (is-some (map-get? vehicle-performance { vehicle-id: vehicle-id })) ERR-VEHICLE-NOT-REGISTERED)

    ;; Store route request
    (map-set route-requests
      { route-id: route-id }
      {
        vehicle-id: vehicle-id,
        origin: origin,
        destination: destination,
        departure-time: departure-time,
        arrival-deadline: arrival-deadline,
        priority-level: priority-level,
        passenger-count: passenger-count,
        vehicle-type: vehicle-type,
        fuel-efficiency: fuel-efficiency,
        status: "pending",
        assigned-route: "",
        estimated-emissions: u0,
        actual-emissions: u0
      }
    )

    ;; Increment route ID
    (var-set next-route-id (+ route-id u1))

    ;; Attempt immediate optimization
    (optimize-route route-id)
  )
)

;; Optimize a specific route
(define-public (optimize-route (route-id uint))
  (let (
    (route-request (unwrap! (map-get? route-requests { route-id: route-id }) ERR-ROUTE-NOT-FOUND))
  )
    ;; Check if route is still pending
    (asserts! (is-eq (get status route-request) "pending") ERR-OPTIMIZATION-FAILED)

    ;; Calculate optimal route
    (let (
      (optimization-result (calculate-optimal-route route-request))
    )
      ;; Update route request with optimization
      (map-set route-requests
        { route-id: route-id }
        (merge route-request {
          status: "optimized",
          assigned-route: (get route optimization-result),
          estimated-emissions: (get emissions optimization-result)
        })
      )

      ;; Store route segments
      (store-route-segments route-id (get segments optimization-result))

      (ok optimization-result)
    )
  )
)

;; Register a vehicle for traffic optimization
(define-public (register-vehicle-for-optimization
  (vehicle-id uint)
  (initial-efficiency uint)
)
  (begin
    (asserts! (> initial-efficiency u0) ERR-INVALID-INPUT)

    (map-set vehicle-performance
      { vehicle-id: vehicle-id }
      {
        total-routes: u0,
        total-distance: u0,
        total-emissions: u0,
        average-efficiency: initial-efficiency,
        congestion-contribution: u0,
        optimization-compliance: u100,
        last-route-time: u0,
        performance-score: u100
      }
    )

    (ok vehicle-id)
  )
)

;; Update real-time traffic conditions
(define-public (update-traffic-conditions
  (zone-id uint)
  (traffic-density uint)
  (average-speed uint)
  (incident-count uint)
  (weather-impact uint)
)
  (begin
    (asserts! (<= traffic-density u100) ERR-INVALID-INPUT)
    (asserts! (<= weather-impact u100) ERR-INVALID-INPUT)

    ;; Store real-time conditions
    (map-set real-time-conditions
      { zone-id: zone-id, timestamp: block-height }
      {
        traffic-density: traffic-density,
        average-speed: average-speed,
        incident-count: incident-count,
        weather-impact: weather-impact,
        construction-impact: u0,
        event-impact: u0
      }
    )

    ;; Update zone congestion
    (update-zone-congestion zone-id traffic-density average-speed)

    (ok true)
  )
)

;; Complete a route and record performance
(define-public (complete-route
  (route-id uint)
  (actual-emissions uint)
  (actual-travel-time uint)
  (route-followed bool)
)
  (let (
    (route-request (unwrap! (map-get? route-requests { route-id: route-id }) ERR-ROUTE-NOT-FOUND))
    (vehicle-id (get vehicle-id route-request))
  )
    ;; Update route completion
    (map-set route-requests
      { route-id: route-id }
      (merge route-request {
        status: "completed",
        actual-emissions: actual-emissions
      })
    )

    ;; Update vehicle performance
    (update-vehicle-performance vehicle-id actual-emissions route-followed)

    ;; Calculate and award incentives
    (calculate-incentives vehicle-id route-request actual-emissions route-followed)

    (ok true)
  )
)

;; Create a new traffic zone
(define-public (create-traffic-zone
  (zone-name (string-ascii 50))
  (coordinates {
    north-lat: (string-ascii 20),
    south-lat: (string-ascii 20),
    east-lng: (string-ascii 20),
    west-lng: (string-ascii 20)
  })
  (max-capacity uint)
  (priority-level uint)
)
  (let (
    (zone-id (var-get next-zone-id))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= priority-level u5) ERR-INVALID-INPUT)

    (map-set traffic-zones
      { zone-id: zone-id }
      {
        zone-name: zone-name,
        coordinates: coordinates,
        current-congestion: u0,
        max-capacity: max-capacity,
        current-vehicles: u0,
        average-speed: u50,
        emission-factor: u10,
        priority-level: priority-level,
        last-updated: block-height
      }
    )

    (var-set next-zone-id (+ zone-id u1))
    (ok zone-id)
  )
)

;; Read-only Functions

;; Get route request details
(define-read-only (get-route-request (route-id uint))
  (map-get? route-requests { route-id: route-id })
)

;; Get traffic zone information
(define-read-only (get-traffic-zone (zone-id uint))
  (map-get? traffic-zones { zone-id: zone-id })
)

;; Get vehicle performance
(define-read-only (get-vehicle-performance (vehicle-id uint))
  (map-get? vehicle-performance { vehicle-id: vehicle-id })
)

;; Get route segment
(define-read-only (get-route-segment (route-id uint) (segment-id uint))
  (map-get? optimized-routes { route-id: route-id, segment-id: segment-id })
)

;; Get real-time conditions
(define-read-only (get-real-time-conditions (zone-id uint) (timestamp uint))
  (map-get? real-time-conditions { zone-id: zone-id, timestamp: timestamp })
)

;; Get total emissions saved
(define-read-only (get-total-emissions-saved)
  (var-get total-emissions-saved)
)

;; Private Functions

;; Calculate optimal route considering all factors
(define-private (calculate-optimal-route
  (route-request {
    vehicle-id: uint,
    origin: (string-ascii 50),
    destination: (string-ascii 50),
    departure-time: uint,
    arrival-deadline: uint,
    priority-level: uint,
    passenger-count: uint,
    vehicle-type: (string-ascii 30),
    fuel-efficiency: uint,
    status: (string-ascii 20),
    assigned-route: (string-ascii 500),
    estimated-emissions: uint,
    actual-emissions: uint
  })
)
  (let (
    (base-emissions (/ u1000 (get fuel-efficiency route-request)))
    (priority-factor (get priority-level route-request))
    (time-constraint (- (get arrival-deadline route-request) (get departure-time route-request)))
  )
    {
      route: "optimized-path-through-zones-1-3-5",
      emissions: (+ base-emissions (* priority-factor u10)),
      segments: (list
        { zone: u1, entry: (get departure-time route-request), exit: (+ (get departure-time route-request) u300) }
        { zone: u3, entry: (+ (get departure-time route-request) u300), exit: (+ (get departure-time route-request) u600) }
        { zone: u5, entry: (+ (get departure-time route-request) u600), exit: (+ (get departure-time route-request) u900) }
      )
    }
  )
)

;; Store route segments in the map
(define-private (store-route-segments
  (route-id uint)
  (segments (list 10 { zone: uint, entry: uint, exit: uint }))
)
  (fold store-single-segment segments { route-id: route-id, segment-index: u0 })
)

;; Store a single route segment
(define-private (store-single-segment
  (segment { zone: uint, entry: uint, exit: uint })
  (context { route-id: uint, segment-index: uint })
)
  (begin
    (map-set optimized-routes
      { route-id: (get route-id context), segment-id: (get segment-index context) }
      {
        zone-id: (get zone segment),
        entry-time: (get entry segment),
        exit-time: (get exit segment),
        speed-limit: u50,
        congestion-factor: u20,
        alternative-available: true,
        emissions-estimate: u50
      }
    )
    { route-id: (get route-id context), segment-index: (+ (get segment-index context) u1) }
  )
)

;; Update zone congestion based on real-time data
(define-private (update-zone-congestion (zone-id uint) (traffic-density uint) (average-speed uint))
  (match (map-get? traffic-zones { zone-id: zone-id })
    zone (map-set traffic-zones
      { zone-id: zone-id }
      (merge zone {
        current-congestion: traffic-density,
        average-speed: average-speed,
        last-updated: block-height
      })
    )
    false
  )
)

;; Update vehicle performance metrics
(define-private (update-vehicle-performance (vehicle-id uint) (actual-emissions uint) (route-followed bool))
  (match (map-get? vehicle-performance { vehicle-id: vehicle-id })
    performance (let (
      (new-total-routes (+ (get total-routes performance) u1))
      (new-total-emissions (+ (get total-emissions performance) actual-emissions))
      (compliance-adjustment (if route-followed u0 u5))
      (current-compliance (get optimization-compliance performance))
      (new-compliance (if (> current-compliance compliance-adjustment)
                         (- current-compliance compliance-adjustment)
                         u0))
    )
      (map-set vehicle-performance
        { vehicle-id: vehicle-id }
        (merge performance {
          total-routes: new-total-routes,
          total-emissions: new-total-emissions,
          optimization-compliance: new-compliance,
          last-route-time: block-height,
          performance-score: (calculate-performance-score new-compliance new-total-emissions new-total-routes)
        })
      )
    )
    false
  )
)

;; Calculate performance score
(define-private (calculate-performance-score (compliance uint) (total-emissions uint) (total-routes uint))
  (let (
    (efficiency-score (if (> total-routes u0) (/ (* u100 u1000) (/ total-emissions total-routes)) u100))
    (compliance-score compliance)
  )
    (/ (+ efficiency-score compliance-score) u2)
  )
)

;; Calculate incentives for route completion
(define-private (calculate-incentives
  (vehicle-id uint)
  (route-request {
    vehicle-id: uint,
    origin: (string-ascii 50),
    destination: (string-ascii 50),
    departure-time: uint,
    arrival-deadline: uint,
    priority-level: uint,
    passenger-count: uint,
    vehicle-type: (string-ascii 30),
    fuel-efficiency: uint,
    status: (string-ascii 20),
    assigned-route: (string-ascii 500),
    estimated-emissions: uint,
    actual-emissions: uint
  })
  (actual-emissions uint)
  (route-followed bool)
)
  (let (
    (estimated-emissions (get estimated-emissions route-request))
    (emissions-saved (if (> estimated-emissions actual-emissions)
                        (- estimated-emissions actual-emissions)
                        u0))
    (cooperation-bonus (if route-followed u50 u0))
    (period (/ block-height u1000)) ;; Group by periods of ~1000 blocks
  )
    (map-set coordination-incentives
      { vehicle-id: vehicle-id, period: period }
      {
        emissions-saved: emissions-saved,
        congestion-reduced: u10, ;; Simplified calculation
        route-efficiency: (if route-followed u100 u50),
        cooperation-score: cooperation-bonus,
        reward-earned: (+ emissions-saved cooperation-bonus),
        penalty-applied: (if route-followed u0 u25)
      }
    )

    ;; Update global emissions saved
    (var-set total-emissions-saved (+ (var-get total-emissions-saved) emissions-saved))
  )
)
