;; Options Contract
;; This contract allows users to create, buy, sell, and exercise options on STX

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-OPTION-NOT-FOUND (err u1001))
(define-constant ERR-OPTION-EXPIRED (err u1002))
(define-constant ERR-ALREADY-EXERCISED (err u1003))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1004))
(define-constant ERR-INVALID-EXPIRY (err u1005))
(define-constant ERR-INVALID-STRIKE-PRICE (err u1006))
(define-constant ERR-OPTION-NOT-OWNED (err u1007))
(define-constant ERR-OPTION-NOT-FOR-SALE (err u1008))
(define-constant ERR-INVALID-PRICE (err u1009))
(define-constant ERR-NOT-WRITER (err u1010))
(define-constant ERR-ALREADY-SETTLED (err u1011))

;; Option Types
(define-constant OPTION-TYPE-CALL u1)
(define-constant OPTION-TYPE-PUT u2)

;; Option Status
(define-constant OPTION-STATUS-ACTIVE u1)
(define-constant OPTION-STATUS-EXERCISED u2)
(define-constant OPTION-STATUS-EXPIRED u3)
(define-constant OPTION-STATUS-FOR-SALE u4)

;; Option data structure
(define-map options
  { option-id: uint }
  {
    writer: principal,
    holder: principal,
    underlying-asset: (string-ascii 32),
    strike-price: uint,
    premium: uint,
    expiration: uint,
    option-type: uint,
    status: uint,
    amount: uint,
    sale-price: (optional uint)
  }
)

;; Option count for generating unique IDs
(define-data-var option-count uint u0)

;; Maps to track options by writer and holder
(define-map options-by-writer 
  { writer: principal } 
  { option-ids: (list 100 uint) }
)

(define-map options-by-holder 
  { holder: principal } 
  { option-ids: (list 100 uint) }
)

;; Get the current option count
(define-read-only (get-option-count)
  (var-get option-count)
)

;; Get option details
(define-read-only (get-option (option-id uint))
  (match (map-get? options { option-id: option-id })
    option (ok option)
    (err ERR-OPTION-NOT-FOUND)
  )
)

;; Get options by writer
(define-read-only (get-options-by-writer (writer principal))
  (default-to { option-ids: (list) } (map-get? options-by-writer { writer: writer }))
)

;; Get options by holder
(define-read-only (get-options-by-holder (holder principal))
  (default-to { option-ids: (list) } (map-get? options-by-holder { holder: holder }))
)

;; Add option ID to list for a writer
;; This is a simplified implementation that just logs but doesn't actually add to a list
;; In a real implementation, you'd want to properly maintain these indexes
(define-private (add-option-to-writer (writer principal) (option-id uint))
  true
)

;; Add option ID to list for a holder
;; This is a simplified implementation that just logs but doesn't actually add to a list
;; In a real implementation, you'd want to properly maintain these indexes
(define-private (add-option-to-holder (holder principal) (option-id uint))
  true
)

;; Remove option ID from list for a holder
;; Note: In a real implementation, you would need to handle this differently
;; This is a simplified approach that doesn't actually remove the option
;; but just demonstrates the concept
(define-private (remove-option-from-holder (holder principal) (option-id uint))
  true
)

;; Create a new option
(define-public (create-option 
    (underlying-asset (string-ascii 32)) 
    (strike-price uint) 
    (premium uint) 
    (expiration uint) 
    (option-type uint)
    (amount uint))
  (let 
    (
      (new-option-id (+ (var-get option-count) u1))
      (current-block-height block-height)
    )
    ;; Validate inputs
    (asserts! (> strike-price u0) (err ERR-INVALID-STRIKE-PRICE))
    (asserts! (> amount u0) (err ERR-INVALID-PRICE))
    (asserts! (> expiration current-block-height) (err ERR-INVALID-EXPIRY))
    (asserts! (or (is-eq option-type OPTION-TYPE-CALL) (is-eq option-type OPTION-TYPE-PUT)) (err ERR-NOT-AUTHORIZED))
    
    ;; Update option count
    (var-set option-count new-option-id)
    
    ;; Create new option
    (map-set options 
      { option-id: new-option-id }
      {
        writer: tx-sender,
        holder: tx-sender,
        underlying-asset: underlying-asset,
        strike-price: strike-price,
        premium: premium,
        expiration: expiration,
        option-type: option-type,
        status: OPTION-STATUS-ACTIVE,
        amount: amount,
        sale-price: none
      }
    )
    
    ;; Update indices
    (add-option-to-writer tx-sender new-option-id)
    (add-option-to-holder tx-sender new-option-id)
    
    ;; Return the new option ID
    (ok new-option-id)
  )
)

;; Buy an option from the writer
(define-public (buy-option (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
    )
    ;; Validate option
    (asserts! (< current-block-height (get expiration option)) (err ERR-OPTION-EXPIRED))
    (asserts! (is-eq (get status option) OPTION-STATUS-ACTIVE) (err ERR-ALREADY-EXERCISED))
    (asserts! (is-eq (get writer option) (get holder option)) (err ERR-NOT-WRITER))
    
    ;; Transfer premium from buyer to writer
    (match (stx-transfer? (get premium option) tx-sender (get writer option))
      success
        (begin
          ;; Update option holder
          (map-set options
            { option-id: option-id }
            (merge option { holder: tx-sender })
          )
          
          ;; Update indices
          (add-option-to-holder tx-sender option-id)
          (remove-option-from-holder (get writer option) option-id)
          
          (ok true)
        )
      error (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

;; List an option for sale
(define-public (list-option-for-sale (option-id uint) (price uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
    )
    ;; Validate option
    (asserts! (< current-block-height (get expiration option)) (err ERR-OPTION-EXPIRED))
    (asserts! (is-eq (get status option) OPTION-STATUS-ACTIVE) (err ERR-ALREADY-EXERCISED))
    (asserts! (is-eq (get holder option) tx-sender) (err ERR-OPTION-NOT-OWNED))
    (asserts! (> price u0) (err ERR-INVALID-PRICE))
    
    ;; Update option status and sale price
    (map-set options
      { option-id: option-id }
      (merge option { 
        status: OPTION-STATUS-FOR-SALE,
        sale-price: (some price)
      })
    )
    
    (ok true)
  )
)

;; Cancel listing an option for sale
(define-public (cancel-option-listing (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
    )
    ;; Validate option
    (asserts! (is-eq (get status option) OPTION-STATUS-FOR-SALE) (err ERR-OPTION-NOT-FOR-SALE))
    (asserts! (is-eq (get holder option) tx-sender) (err ERR-OPTION-NOT-OWNED))
    
    ;; Update option status and sale price
    (map-set options
      { option-id: option-id }
      (merge option { 
        status: OPTION-STATUS-ACTIVE,
        sale-price: none
      })
    )
    
    (ok true)
  )
)

;; Buy a listed option from another user
(define-public (buy-listed-option (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
      (sale-price (default-to u0 (get sale-price option)))
    )
    ;; Validate option
    (asserts! (< current-block-height (get expiration option)) (err ERR-OPTION-EXPIRED))
    (asserts! (is-eq (get status option) OPTION-STATUS-FOR-SALE) (err ERR-OPTION-NOT-FOR-SALE))
    (asserts! (> sale-price u0) (err ERR-INVALID-PRICE))
    
    ;; Transfer payment from buyer to current holder
    (match (stx-transfer? sale-price tx-sender (get holder option))
      success 
        (begin
          ;; Update option holder and status
          (map-set options
            { option-id: option-id }
            (merge option { 
              holder: tx-sender,
              status: OPTION-STATUS-ACTIVE,
              sale-price: none
            })
          )
          
          ;; Update indices
          (add-option-to-holder tx-sender option-id)
          (remove-option-from-holder (get holder option) option-id)
          
          (ok true)
        )
      error (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

;; Exercise a CALL option
(define-public (exercise-call-option (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
      (total-strike-amount (* (get strike-price option) (get amount option)))
    )
    ;; Validate option
    (asserts! (< current-block-height (get expiration option)) (err ERR-OPTION-EXPIRED))
    (asserts! (is-eq (get status option) OPTION-STATUS-ACTIVE) (err ERR-ALREADY-EXERCISED))
    (asserts! (is-eq (get option-type option) OPTION-TYPE-CALL) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get holder option) tx-sender) (err ERR-OPTION-NOT-OWNED))
    
    ;; Transfer strike price from option holder to writer
    (match (stx-transfer? total-strike-amount tx-sender (get writer option))
      success
        (begin
          ;; Update option status
          (map-set options
            { option-id: option-id }
            (merge option { status: OPTION-STATUS-EXERCISED })
          )
          
          (ok true)
        )
      error (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

;; Exercise a PUT option
(define-public (exercise-put-option (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
      (total-strike-amount (* (get strike-price option) (get amount option)))
    )
    ;; Validate option
    (asserts! (< current-block-height (get expiration option)) (err ERR-OPTION-EXPIRED))
    (asserts! (is-eq (get status option) OPTION-STATUS-ACTIVE) (err ERR-ALREADY-EXERCISED))
    (asserts! (is-eq (get option-type option) OPTION-TYPE-PUT) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get holder option) tx-sender) (err ERR-OPTION-NOT-OWNED))
    
    ;; Transfer strike price from writer to option holder
    (match (stx-transfer? total-strike-amount (get writer option) tx-sender)
      success
        (begin
          ;; Update option status
          (map-set options
            { option-id: option-id }
            (merge option { status: OPTION-STATUS-EXERCISED })
          )
          
          (ok true)
        )
      error (err ERR-INSUFFICIENT-BALANCE)
    )
  )
)

;; Expire an option (can be called by anyone once the expiration block height is reached)
(define-public (expire-option (option-id uint))
  (let 
    (
      (option (unwrap! (map-get? options { option-id: option-id }) (err ERR-OPTION-NOT-FOUND)))
      (current-block-height block-height)
    )
    ;; Validate option can be expired
    (asserts! (>= current-block-height (get expiration option)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq (get status option) OPTION-STATUS-EXPIRED)) (err ERR-ALREADY-SETTLED))
    (asserts! (not (is-eq (get status option) OPTION-STATUS-EXERCISED)) (err ERR-ALREADY-EXERCISED))
    
    ;; Update option status
    (map-set options
      { option-id: option-id }
      (merge option { status: OPTION-STATUS-EXPIRED })
    )
    
    (ok true)
  )
)

;; Get all active options
;; In a real implementation, you would iterate through all options
(define-read-only (get-active-options)
  (let ((option-count-val (var-get option-count)))
    (if (> option-count-val u0)
      ;; Just return the first option if any exist
      (match (map-get? options { option-id: u1 })
        option 
          (list { 
            option-id: u1, 
            writer: (get writer option),
            holder: (get holder option),
            underlying-asset: (get underlying-asset option),
            strike-price: (get strike-price option),
            premium: (get premium option),
            expiration: (get expiration option),
            option-type: (get option-type option),
            amount: (get amount option)
          })
        (list))
      (list))
  )
)

;; Initialize contract
(begin
  (var-get option-count))