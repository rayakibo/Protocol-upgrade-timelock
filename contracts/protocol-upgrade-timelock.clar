;; =====================================================
;; ProtocolUpgradeTimelock
;; Mandatory delay for protocol upgrades
;; =====================================================

;; -----------------------------
;; Data Variables
;; -----------------------------

(define-data-var governor principal tx-sender)
(define-data-var delay uint u144) ;; default delay in blocks

;; -----------------------------
;; Data Maps
;; -----------------------------

;; upgrade-id => upgrade proposal
(define-map upgrades
  uint
  {
    target: principal,
    scheduled-at: uint,
    executable-at: uint,
    executed: bool
  }
)

(define-data-var upgrade-count uint u0)

;; -----------------------------
;; Errors
;; -----------------------------

(define-constant ERR-NOT-GOVERNOR u100)
(define-constant ERR-NOT-READY u101)
(define-constant ERR-ALREADY-EXECUTED u102)
(define-constant ERR-NOT-FOUND u103)

;; -----------------------------
;; Helpers
;; -----------------------------

(define-read-only (is-governor)
  (is-eq tx-sender (var-get governor))
)

;; -----------------------------
;; Schedule Upgrade
;; -----------------------------

(define-public (schedule-upgrade
  (target principal)
)
  (begin
    (asserts! (is-governor) (err ERR-NOT-GOVERNOR))

    (let (
      (id (var-get upgrade-count))
      (now stacks-block-height)
      (exec-at (+ stacks-block-height (var-get delay)))
    )
      (map-set upgrades id {
        target: target,
        scheduled-at: now,
        executable-at: exec-at,
        executed: false
      })

      (var-set upgrade-count (+ id u1))
      (ok id)
    )
  )
)

;; -----------------------------
;; Mark Executed
;; -----------------------------

(define-public (mark-executed (upgrade-id uint))
  (begin
    (asserts! (is-governor) (err ERR-NOT-GOVERNOR))

    (let ((u (map-get? upgrades upgrade-id)))
      (match u data
        (begin
          (asserts!
            (>= stacks-block-height (get executable-at data))
            (err ERR-NOT-READY)
          )
          (asserts! (not (get executed data)) (err ERR-ALREADY-EXECUTED))

          (map-set upgrades upgrade-id {
            target: (get target data),
            scheduled-at: (get scheduled-at data),
            executable-at: (get executable-at data),
            executed: true
          })

          (ok true)
        )
        (err ERR-NOT-FOUND)
      )
    )
  )
)

;; -----------------------------
;; Admin Controls
;; -----------------------------

(define-public (update-delay (new-delay uint))
  (begin
    (asserts! (is-governor) (err ERR-NOT-GOVERNOR))
    (asserts! (> new-delay u0) (err ERR-NOT-READY))
    (var-set delay new-delay)
    (ok true)
  )
)

;; -----------------------------
;; Read-only Views
;; -----------------------------

(define-read-only (get-upgrade (upgrade-id uint))
  (map-get? upgrades upgrade-id)
)

(define-read-only (get-delay)
  (var-get delay)
)
