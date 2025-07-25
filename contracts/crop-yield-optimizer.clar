;; Crop Yield Optimization Contract
;; Manages crop yield predictions, optimization strategies, and performance tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-FARM-NOT-FOUND (err u102))
(define-constant ERR-CROP-NOT-FOUND (err u103))

;; Data Variables
(define-data-var next-farm-id uint u1)
(define-data-var next-crop-id uint u1)

;; Data Maps
(define-map farms
  { farm-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    location: (string-ascii 200),
    total-area: uint,
    created-at: uint
  }
)

(define-map crops
  { crop-id: uint }
  {
    farm-id: uint,
    crop-type: (string-ascii 50),
    planted-area: uint,
    planting-date: uint,
    expected-harvest: uint,
    predicted-yield: uint,
    actual-yield: (optional uint),
    optimization-score: uint
  }
)

(define-map yield-predictions
  { farm-id: uint, crop-type: (string-ascii 50), season: uint }
  {
    ai-prediction: uint,
    sensor-data-hash: (string-ascii 64),
    confidence-level: uint,
    factors: (list 10 (string-ascii 50)),
    created-at: uint
  }
)

(define-map optimization-strategies
  { strategy-id: uint }
  {
    farm-id: uint,
    crop-type: (string-ascii 50),
    strategy-name: (string-ascii 100),
    parameters: (list 20 (string-ascii 100)),
    expected-improvement: uint,
    implementation-cost: uint,
    status: (string-ascii 20)
  }
)

;; Authorization Functions
(define-private (is-farm-owner (farm-id uint) (user principal))
  (match (map-get? farms { farm-id: farm-id })
    farm-data (is-eq (get owner farm-data) user)
    false
  )
)

;; Farm Management Functions
(define-public (register-farm (name (string-ascii 100)) (location (string-ascii 200)) (total-area uint))
  (let ((farm-id (var-get next-farm-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> total-area u0) ERR-INVALID-INPUT)

    (map-set farms
      { farm-id: farm-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        total-area: total-area,
        created-at: block-height
      }
    )

    (var-set next-farm-id (+ farm-id u1))
    (ok farm-id)
  )
)

;; Crop Management Functions
(define-public (register-crop
  (farm-id uint)
  (crop-type (string-ascii 50))
  (planted-area uint)
  (planting-date uint)
  (expected-harvest uint)
)
  (let ((crop-id (var-get next-crop-id)))
    (asserts! (is-farm-owner farm-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> planted-area u0) ERR-INVALID-INPUT)
    (asserts! (< planting-date expected-harvest) ERR-INVALID-INPUT)

    (map-set crops
      { crop-id: crop-id }
      {
        farm-id: farm-id,
        crop-type: crop-type,
        planted-area: planted-area,
        planting-date: planting-date,
        expected-harvest: expected-harvest,
        predicted-yield: u0,
        actual-yield: none,
        optimization-score: u0
      }
    )

    (var-set next-crop-id (+ crop-id u1))
    (ok crop-id)
  )
)

;; Yield Prediction Functions
(define-public (record-yield-prediction
  (farm-id uint)
  (crop-type (string-ascii 50))
  (season uint)
  (ai-prediction uint)
  (sensor-data-hash (string-ascii 64))
  (confidence-level uint)
  (factors (list 10 (string-ascii 50)))
)
  (begin
    (asserts! (is-farm-owner farm-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> ai-prediction u0) ERR-INVALID-INPUT)
    (asserts! (<= confidence-level u100) ERR-INVALID-INPUT)

    (map-set yield-predictions
      { farm-id: farm-id, crop-type: crop-type, season: season }
      {
        ai-prediction: ai-prediction,
        sensor-data-hash: sensor-data-hash,
        confidence-level: confidence-level,
        factors: factors,
        created-at: block-height
      }
    )

    (ok true)
  )
)

;; Optimization Strategy Functions
(define-public (create-optimization-strategy
  (farm-id uint)
  (crop-type (string-ascii 50))
  (strategy-name (string-ascii 100))
  (parameters (list 20 (string-ascii 100)))
  (expected-improvement uint)
  (implementation-cost uint)
)
  (let ((strategy-id (+ (var-get next-farm-id) (var-get next-crop-id))))
    (asserts! (is-farm-owner farm-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> expected-improvement u0) ERR-INVALID-INPUT)

    (map-set optimization-strategies
      { strategy-id: strategy-id }
      {
        farm-id: farm-id,
        crop-type: crop-type,
        strategy-name: strategy-name,
        parameters: parameters,
        expected-improvement: expected-improvement,
        implementation-cost: implementation-cost,
        status: "proposed"
      }
    )

    (ok strategy-id)
  )
)

;; Yield Recording Functions
(define-public (record-actual-yield (crop-id uint) (actual-yield uint))
  (match (map-get? crops { crop-id: crop-id })
    crop-data
    (begin
      (asserts! (is-farm-owner (get farm-id crop-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (> actual-yield u0) ERR-INVALID-INPUT)

      (map-set crops
        { crop-id: crop-id }
        (merge crop-data { actual-yield: (some actual-yield) })
      )

      (ok true)
    )
    ERR-CROP-NOT-FOUND
  )
)

;; Analytics Functions
(define-read-only (calculate-yield-efficiency (crop-id uint))
  (match (map-get? crops { crop-id: crop-id })
    crop-data
    (match (get actual-yield crop-data)
      actual
      (if (> (get predicted-yield crop-data) u0)
        (ok (/ (* actual u100) (get predicted-yield crop-data)))
        (ok u0)
      )
      (ok u0)
    )
    ERR-CROP-NOT-FOUND
  )
)

;; Read-only Functions
(define-read-only (get-farm-info (farm-id uint))
  (map-get? farms { farm-id: farm-id })
)

(define-read-only (get-crop-info (crop-id uint))
  (map-get? crops { crop-id: crop-id })
)

(define-read-only (get-yield-prediction (farm-id uint) (crop-type (string-ascii 50)) (season uint))
  (map-get? yield-predictions { farm-id: farm-id, crop-type: crop-type, season: season })
)

(define-read-only (get-optimization-strategy (strategy-id uint))
  (map-get? optimization-strategies { strategy-id: strategy-id })
)
