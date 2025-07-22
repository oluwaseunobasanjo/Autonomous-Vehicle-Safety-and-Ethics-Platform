;; Pedestrian and Cyclist Protection Contract
;; Ensures autonomous vehicles prioritize vulnerable road user safety

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-ZONE-NOT-FOUND (err u402))
(define-constant ERR-INCIDENT-NOT-FOUND (err u403))
(define-constant ERR-SAFETY-VIOLATION (err u404))
(define-constant ERR-EMERGENCY-ACTIVE (err u405))

;; Data Variables
(define-data-var next-safety-zone-id uint u1)
(define-data-var next-incident-id uint u1)
(define-data-var emergency-protection-mode bool false)
(define-data-var global-safety-level uint u3) ;; 1-5 scale, 5 being maximum protection

;; Data Maps
(define-map safety-zones
  { zone-id: uint }
  {
    zone-name: (string-ascii 50),
    zone-type: (string-ascii 30), ;; "school", "hospital", "park", "crosswalk", "bike-lane"
    coordinates: {
      center-lat: (string-ascii 20),
      center-lng: (string-ascii 20),
      radius: uint ;; in meters
    },
    protection-level: uint, ;; 1-5 scale
    speed-limit: uint, ;; km/h
    pedestrian-priority: bool,
    cyclist-priority: bool,
    active-hours: {
      start-hour: uint,
      end-hour: uint
    },
    current-pedestrians: uint,
    current-cyclists: uint,
    incident-count: uint,
    last-updated: uint
  }
)

(define-map vulnerable-user-tracking
  { user-id: uint }
  {
    user-type: (string-ascii 20), ;; "pedestrian", "cyclist", "wheelchair", "child", "elderly"
    current-location: {
      lat: (string-ascii 20),
      lng: (string-ascii 20),
      zone-id: uint
    },
    movement-pattern: {
      speed: uint, ;; m/s
      direction: uint, ;; degrees
      predictability: uint ;; 1-100 scale
    },
    safety-profile: {
      age-group: (string-ascii 20),
      mobility-level: uint, ;; 1-5 scale
      visibility-level: uint, ;; 1-5 scale
      reaction-time: uint ;; milliseconds
    },
    last-seen: uint,
    risk-level: uint ;; 1-100 scale
  }
)

(define-map safety-incidents
  { incident-id: uint }
  {
    incident-type: (string-ascii 50), ;; "near-miss", "collision", "violation", "emergency-stop"
    zone-id: uint,
    vehicle-id: uint,
    vulnerable-users: (list 5 uint), ;; user IDs involved
    severity: uint, ;; 1-10 scale
    vehicle-speed: uint,
    stopping-distance: uint,
    reaction-time: uint,
    weather-conditions: uint,
    visibility-conditions: uint,
    timestamp: uint,
    investigated: bool,
    preventable: bool
  }
)

(define-map vehicle-safety-records
  { vehicle-id: uint }
  {
    total-interactions: uint,
    safe-interactions: uint,
    near-misses: uint,
    violations: uint,
    emergency-stops: uint,
    average-reaction-time: uint,
    safety-score: uint, ;; 1-100 scale
    last-violation: uint,
    certification-level: uint, ;; 1-5 scale
    protection-compliance: uint ;; percentage
  }
)

(define-map protection-protocols
  { protocol-id: uint }
  {
    protocol-name: (string-ascii 50),
    trigger-conditions: (string-ascii 200),
    required-actions: (string-ascii 300),
    minimum-distance: uint, ;; meters
    maximum-speed: uint, ;; km/h
    alert-threshold: uint, ;; milliseconds
    applicable-zones: (list 10 uint),
    user-types: (list 5 (string-ascii 20)),
    active: bool,
    priority: uint
  }
)

(define-map real-time-alerts
  { alert-id: uint }
  {
    zone-id: uint,
    alert-type: (string-ascii 30), ;; "high-pedestrian-activity", "school-hours", "event", "weather"
    severity: uint, ;; 1-5 scale
    affected-area: uint, ;; radius in meters
    duration: uint, ;; expected duration in minutes
    special-instructions: (string-ascii 200),
    vehicles-notified: uint,
    timestamp: uint,
    active: bool
  }
)

;; Initialize default safety zones
(map-set safety-zones { zone-id: u1 }
  {
    zone-name: "elementary-school-main",
    zone-type: "school",
    coordinates: { center-lat: "37.7849", center-lng: "-122.4194", radius: u200 },
    protection-level: u5,
    speed-limit: u25,
    pedestrian-priority: true,
    cyclist-priority: true,
    active-hours: { start-hour: u7, end-hour: u18 },
    current-pedestrians: u0,
    current-cyclists: u0,
    incident-count: u0,
    last-updated: u0
  })

;; Initialize default protection protocols
(map-set protection-protocols { protocol-id: u1 }
  {
    protocol-name: "school-zone-protection",
    trigger-conditions: "school hours and high pedestrian activity",
    required-actions: "reduce speed to 25km/h, increase following distance, activate pedestrian detection",
    minimum-distance: u50,
    maximum-speed: u25,
    alert-threshold: u2000,
    applicable-zones: (list u1),
    user-types: (list "child" "pedestrian" "cyclist"),
    active: true,
    priority: u5
  })

;; Public Functions

;; Create a new safety zone
(define-public (create-safety-zone
  (zone-name (string-ascii 50))
  (zone-type (string-ascii 30))
  (coordinates {
    center-lat: (string-ascii 20),
    center-lng: (string-ascii 20),
    radius: uint
  })
  (protection-level uint)
  (speed-limit uint)
  (active-hours { start-hour: uint, end-hour: uint })
)
  (let (
    (zone-id (var-get next-safety-zone-id))
  )
    ;; Validate input
    (asserts! (<= protection-level u5) ERR-INVALID-INPUT)
    (asserts! (<= speed-limit u100) ERR-INVALID-INPUT)
    (asserts! (< (get start-hour active-hours) u24) ERR-INVALID-INPUT)
    (asserts! (< (get end-hour active-hours) u24) ERR-INVALID-INPUT)

    ;; Create safety zone
    (map-set safety-zones
      { zone-id: zone-id }
      {
        zone-name: zone-name,
        zone-type: zone-type,
        coordinates: coordinates,
        protection-level: protection-level,
        speed-limit: speed-limit,
        pedestrian-priority: true,
        cyclist-priority: (or (is-eq zone-type "bike-lane") (is-eq zone-type "park")),
        active-hours: active-hours,
        current-pedestrians: u0,
        current-cyclists: u0,
        incident-count: u0,
        last-updated: block-height
      }
    )

    (var-set next-safety-zone-id (+ zone-id u1))
    (ok zone-id)
  )
)

;; Register a vulnerable road user
(define-public (register-vulnerable-user
  (user-id uint)
  (user-type (string-ascii 20))
  (location { lat: (string-ascii 20), lng: (string-ascii 20), zone-id: uint })
  (safety-profile {
    age-group: (string-ascii 20),
    mobility-level: uint,
    visibility-level: uint,
    reaction-time: uint
  })
)
  (begin
    ;; Validate input
    (asserts! (<= (get mobility-level safety-profile) u5) ERR-INVALID-INPUT)
    (asserts! (<= (get visibility-level safety-profile) u5) ERR-INVALID-INPUT)
    (asserts! (> (get reaction-time safety-profile) u0) ERR-INVALID-INPUT)

    ;; Calculate initial risk level
    (let (
      (risk-level (calculate-user-risk-level user-type safety-profile))
    )
      ;; Register user
      (map-set vulnerable-user-tracking
        { user-id: user-id }
        {
          user-type: user-type,
          current-location: location,
          movement-pattern: {
            speed: u0,
            direction: u0,
            predictability: u50
          },
          safety-profile: safety-profile,
          last-seen: block-height,
          risk-level: risk-level
        }
      )

      ;; Update zone user count
      (update-zone-user-count (get zone-id location) user-type true)

      (ok user-id)
    )
  )
)

;; Report a safety incident
(define-public (report-safety-incident
  (incident-type (string-ascii 50))
  (zone-id uint)
  (vehicle-id uint)
  (vulnerable-users (list 5 uint))
  (severity uint)
  (vehicle-speed uint)
  (stopping-distance uint)
  (reaction-time uint)
)
  (let (
    (incident-id (var-get next-incident-id))
  )
    ;; Validate input
    (asserts! (<= severity u10) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? safety-zones { zone-id: zone-id })) ERR-ZONE-NOT-FOUND)

    ;; Store incident
    (map-set safety-incidents
      { incident-id: incident-id }
      {
        incident-type: incident-type,
        zone-id: zone-id,
        vehicle-id: vehicle-id,
        vulnerable-users: vulnerable-users,
        severity: severity,
        vehicle-speed: vehicle-speed,
        stopping-distance: stopping-distance,
        reaction-time: reaction-time,
        weather-conditions: u1, ;; Default to clear
        visibility-conditions: u5, ;; Default to good
        timestamp: block-height,
        investigated: false,
        preventable: false
      }
    )

    ;; Update zone incident count
    (update-zone-incident-count zone-id)

    ;; Update vehicle safety record
    (update-vehicle-safety-record vehicle-id incident-type severity)

    ;; Check if emergency protection should be activated
    (if (>= severity u8)
      (var-set emergency-protection-mode true)
      true
    )

    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

;; Update vulnerable user location
(define-public (update-user-location
  (user-id uint)
  (new-location { lat: (string-ascii 20), lng: (string-ascii 20), zone-id: uint })
  (movement-data { speed: uint, direction: uint, predictability: uint })
)
  (let (
    (user-data (unwrap! (map-get? vulnerable-user-tracking { user-id: user-id }) ERR-INVALID-INPUT))
    (old-zone-id (get zone-id (get current-location user-data)))
  )
    ;; Update user tracking data
    (map-set vulnerable-user-tracking
      { user-id: user-id }
      (merge user-data {
        current-location: new-location,
        movement-pattern: movement-data,
        last-seen: block-height,
        risk-level: (calculate-movement-risk movement-data (get safety-profile user-data))
      })
    )

    ;; Update zone counts if user moved zones
    (if (not (is-eq old-zone-id (get zone-id new-location)))
      (begin
        (update-zone-user-count old-zone-id (get user-type user-data) false)
        (update-zone-user-count (get zone-id new-location) (get user-type user-data) true)
      )
      true
    )

    (ok true)
  )
)

;; Register vehicle for safety monitoring
(define-public (register-vehicle-safety
  (vehicle-id uint)
  (certification-level uint)
)
  (begin
    (asserts! (<= certification-level u5) ERR-INVALID-INPUT)

    (map-set vehicle-safety-records
      { vehicle-id: vehicle-id }
      {
        total-interactions: u0,
        safe-interactions: u0,
        near-misses: u0,
        violations: u0,
        emergency-stops: u0,
        average-reaction-time: u1000,
        safety-score: u100,
        last-violation: u0,
        certification-level: certification-level,
        protection-compliance: u100
      }
    )

    (ok vehicle-id)
  )
)

;; Create real-time safety alert
(define-public (create-safety-alert
  (alert-id uint)
  (zone-id uint)
  (alert-type (string-ascii 30))
  (severity uint)
  (duration uint)
  (special-instructions (string-ascii 200))
)
  (begin
    ;; Validate input
    (asserts! (<= severity u5) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? safety-zones { zone-id: zone-id })) ERR-ZONE-NOT-FOUND)

    ;; Create alert
    (map-set real-time-alerts
      { alert-id: alert-id }
      {
        zone-id: zone-id,
        alert-type: alert-type,
        severity: severity,
        affected-area: u100, ;; Default 100m radius
        duration: duration,
        special-instructions: special-instructions,
        vehicles-notified: u0,
        timestamp: block-height,
        active: true
      }
    )

    ;; If high severity, activate emergency protection
    (if (>= severity u4)
      (var-set emergency-protection-mode true)
      true
    )

    (ok alert-id)
  )
)

;; Set global safety level (admin only)
(define-public (set-global-safety-level (new-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-level u5) ERR-INVALID-INPUT)

    (var-set global-safety-level new-level)
    (ok new-level)
  )
)

;; Read-only Functions

;; Get safety zone information
(define-read-only (get-safety-zone (zone-id uint))
  (map-get? safety-zones { zone-id: zone-id })
)

;; Get vulnerable user data
(define-read-only (get-vulnerable-user (user-id uint))
  (map-get? vulnerable-user-tracking { user-id: user-id })
)

;; Get safety incident details
(define-read-only (get-safety-incident (incident-id uint))
  (map-get? safety-incidents { incident-id: incident-id })
)

;; Get vehicle safety record
(define-read-only (get-vehicle-safety-record (vehicle-id uint))
  (map-get? vehicle-safety-records { vehicle-id: vehicle-id })
)

;; Get protection protocol
(define-read-only (get-protection-protocol (protocol-id uint))
  (map-get? protection-protocols { protocol-id: protocol-id })
)

;; Get real-time alert
(define-read-only (get-real-time-alert (alert-id uint))
  (map-get? real-time-alerts { alert-id: alert-id })
)

;; Check if emergency protection is active
(define-read-only (is-emergency-protection-active)
  (var-get emergency-protection-mode)
)

;; Get current global safety level
(define-read-only (get-global-safety-level)
  (var-get global-safety-level)
)

;; Private Functions

;; Calculate user risk level based on profile
(define-private (calculate-user-risk-level
  (user-type (string-ascii 20))
  (safety-profile {
    age-group: (string-ascii 20),
    mobility-level: uint,
    visibility-level: uint,
    reaction-time: uint
  })
)
  (let (
    (base-risk (if (is-eq user-type "child") u80
                (if (is-eq user-type "elderly") u70
                (if (is-eq user-type "wheelchair") u75
                u50))))
    (mobility-factor (- u6 (get mobility-level safety-profile)))
    (visibility-factor (- u6 (get visibility-level safety-profile)))
    (reaction-factor (/ (get reaction-time safety-profile) u100))
  )
    (let (
      (total-risk (+ base-risk (* mobility-factor u5) (* visibility-factor u5) reaction-factor))
    )
      (if (> total-risk u100) u100 total-risk)
    )
  )
)

;; Calculate movement-based risk
(define-private (calculate-movement-risk
  (movement-data { speed: uint, direction: uint, predictability: uint })
  (safety-profile {
    age-group: (string-ascii 20),
    mobility-level: uint,
    visibility-level: uint,
    reaction-time: uint
  })
)
  (let (
    (speed-risk (if (> (get speed movement-data) u5) u20 u0))
    (predictability-risk (- u100 (get predictability movement-data)))
    (base-risk (calculate-user-risk-level "pedestrian" safety-profile))
  )
    (let (
      (total-risk (+ base-risk speed-risk (/ predictability-risk u5)))
    )
      (if (> total-risk u100) u100 total-risk)
    )
  )
)

;; Update zone user count
(define-private (update-zone-user-count (zone-id uint) (user-type (string-ascii 20)) (increment bool))
  (match (map-get? safety-zones { zone-id: zone-id })
    zone (let (
      (current-pedestrians (get current-pedestrians zone))
      (current-cyclists (get current-cyclists zone))
    )
      (if (or (is-eq user-type "pedestrian") (is-eq user-type "child") (is-eq user-type "elderly"))
        (map-set safety-zones
          { zone-id: zone-id }
          (merge zone {
            current-pedestrians: (if increment
                                   (+ current-pedestrians u1)
                                   (if (> current-pedestrians u0) (- current-pedestrians u1) u0)),
            last-updated: block-height
          })
        )
        (if (is-eq user-type "cyclist")
          (map-set safety-zones
            { zone-id: zone-id }
            (merge zone {
              current-cyclists: (if increment
                                 (+ current-cyclists u1)
                                 (if (> current-cyclists u0) (- current-cyclists u1) u0)),
              last-updated: block-height
            })
          )
          true
        )
      )
    )
    false
  )
)

;; Update zone incident count
(define-private (update-zone-incident-count (zone-id uint))
  (match (map-get? safety-zones { zone-id: zone-id })
    zone (map-set safety-zones
      { zone-id: zone-id }
      (merge zone {
        incident-count: (+ (get incident-count zone) u1),
        last-updated: block-height
      })
    )
    false
  )
)

;; Update vehicle safety record
(define-private (update-vehicle-safety-record (vehicle-id uint) (incident-type (string-ascii 50)) (severity uint))
  (match (map-get? vehicle-safety-records { vehicle-id: vehicle-id })
    record (let (
      (new-total (+ (get total-interactions record) u1))
      (new-violations (if (>= severity u5) (+ (get violations record) u1) (get violations record)))
      (new-near-misses (if (and (>= severity u3) (< severity u5)) (+ (get near-misses record) u1) (get near-misses record)))
      (new-safe (if (< severity u3) (+ (get safe-interactions record) u1) (get safe-interactions record)))
    )
      (map-set vehicle-safety-records
        { vehicle-id: vehicle-id }
        (merge record {
          total-interactions: new-total,
          safe-interactions: new-safe,
          near-misses: new-near-misses,
          violations: new-violations,
          last-violation: (if (>= severity u5) block-height (get last-violation record)),
          safety-score: (calculate-safety-score new-safe new-total new-violations)
        })
      )
    )
    false
  )
)

;; Calculate vehicle safety score
(define-private (calculate-safety-score (safe-interactions uint) (total-interactions uint) (violations uint))
  (if (is-eq total-interactions u0)
    u100
    (let (
      (safe-percentage (/ (* safe-interactions u100) total-interactions))
      (violation-penalty (* violations u10))
    )
      (if (> safe-percentage violation-penalty)
        (- safe-percentage violation-penalty)
        u0
      )
    )
  )
)
