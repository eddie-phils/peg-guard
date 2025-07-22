;; PegGuard - Stablecoin Depeg Protection Insurance Protocol
;; A parametric insurance system for DeFi stablecoin depeg risks

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-policy-expired (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-no-depeg (err u106))
(define-constant err-invalid-threshold (err u107))

;; Data Variables
(define-data-var policy-counter uint u0)
(define-data-var pool-balance uint u0)
(define-data-var premium-rate uint u50) ;; 0.5% (50 basis points)

;; Data Maps
(define-map policies 
  { policy-id: uint }
  {
    holder: principal,
    stablecoin: (string-ascii 10),
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    depeg-threshold: uint, ;; basis points below peg (e.g., 500 = 5%)
    claimed: bool
  }
)

(define-map stablecoin-prices
  { stablecoin: (string-ascii 10) }
  { 
    price: uint, ;; price in basis points (10000 = $1.00)
    last-updated: uint 
  }
)

(define-map user-policies
  { user: principal }
  { policy-ids: (list 50 uint) }
)

;; Pool management for liquidity providers
(define-map liquidity-providers
  { provider: principal }
  { 
    amount-deposited: uint,
    share-tokens: uint,
    deposit-block: uint
  }
)

(define-data-var total-share-tokens uint u0)

;; Public Functions

;; Purchase insurance policy
(define-public (purchase-policy 
  (stablecoin (string-ascii 10))
  (coverage-amount uint)
  (duration-blocks uint)
  (depeg-threshold uint))
  (let (
    (policy-id (+ (var-get policy-counter) u1))
    (premium (calculate-premium coverage-amount duration-blocks))
    (current-block block-height)
    (end-block (+ current-block duration-blocks))
  )
    (asserts! (> coverage-amount u0) err-invalid-amount)
    (asserts! (and (>= depeg-threshold u100) (<= depeg-threshold u2000)) err-invalid-threshold)
    (asserts! (>= (stx-get-balance tx-sender) premium) err-insufficient-funds)
    
    ;; Transfer premium to contract
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    ;; Add premium to pool
    (var-set pool-balance (+ (var-get pool-balance) premium))
    
    ;; Create policy
    (map-set policies 
      { policy-id: policy-id }
      {
        holder: tx-sender,
        stablecoin: stablecoin,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        start-block: current-block,
        end-block: end-block,
        depeg-threshold: depeg-threshold,
        claimed: false
      }
    )
    
    ;; Update user policies list
    (let ((current-policies (default-to { policy-ids: (list) } 
                            (map-get? user-policies { user: tx-sender }))))
      (map-set user-policies 
        { user: tx-sender }
        { policy-ids: (unwrap! (as-max-len? (append (get policy-ids current-policies) policy-id) u50) err-invalid-amount) }
      )
    )
    
    ;; Update counter
    (var-set policy-counter policy-id)
    
    (ok policy-id)
  )
)

;; Claim payout when depeg occurs
(define-public (claim-payout (policy-id uint))
  (let (
    (policy (unwrap! (map-get? policies { policy-id: policy-id }) err-not-found))
    (current-price (get-stablecoin-price (get stablecoin policy)))
  )
    ;; Verify policy holder
    (asserts! (is-eq tx-sender (get holder policy)) err-owner-only)
    
    ;; Check if policy is still valid
    (asserts! (<= block-height (get end-block policy)) err-policy-expired)
    
    ;; Check if not already claimed
    (asserts! (not (get claimed policy)) err-already-claimed)
    
    ;; Check if depeg threshold is breached
    (asserts! (< current-price (- u10000 (get depeg-threshold policy))) err-no-depeg)
    
    ;; Calculate payout based on depeg severity
    (let ((payout (calculate-payout policy current-price)))
      
      ;; Ensure pool has sufficient funds
      (asserts! (>= (var-get pool-balance) payout) err-insufficient-funds)
      
      ;; Transfer payout
      (try! (as-contract (stx-transfer? payout tx-sender (get holder policy))))
      
      ;; Update pool balance
      (var-set pool-balance (- (var-get pool-balance) payout))
      
      ;; Mark policy as claimed
      (map-set policies 
        { policy-id: policy-id }
        (merge policy { claimed: true })
      )
      
      (ok payout)
    )
  )
)

;; Liquidity provider functions
(define-public (provide-liquidity (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-funds)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Calculate share tokens to mint
    (let (
      (current-pool (var-get pool-balance))
      (total-shares (var-get total-share-tokens))
      (new-shares (if (is-eq total-shares u0)
                    amount ;; First deposit gets 1:1 ratio
                    (/ (* amount total-shares) current-pool)))
    )
      ;; Update pool balance
      (var-set pool-balance (+ current-pool amount))
      
      ;; Update total share tokens
      (var-set total-share-tokens (+ total-shares new-shares))
      
      ;; Update provider record
      (let ((current-provider (default-to 
                               { amount-deposited: u0, share-tokens: u0, deposit-block: u0 }
                               (map-get? liquidity-providers { provider: tx-sender }))))
        (map-set liquidity-providers
          { provider: tx-sender }
          {
            amount-deposited: (+ (get amount-deposited current-provider) amount),
            share-tokens: (+ (get share-tokens current-provider) new-shares),
            deposit-block: block-height
          }
        )
      )
      
      (ok new-shares)
    )
  )
)

(define-public (withdraw-liquidity (share-amount uint))
  (let (
    (provider-info (unwrap! (map-get? liquidity-providers { provider: tx-sender }) err-not-found))
    (total-shares (var-get total-share-tokens))
    (current-pool (var-get pool-balance))
  )
    (asserts! (<= share-amount (get share-tokens provider-info)) err-insufficient-funds)
    (asserts! (> total-shares u0) err-insufficient-funds)
    
    ;; Calculate withdrawal amount
    (let ((withdrawal-amount (/ (* share-amount current-pool) total-shares)))
      
      ;; Transfer STX back to provider
      (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
      
      ;; Update pool balance
      (var-set pool-balance (- current-pool withdrawal-amount))
      
      ;; Update total shares
      (var-set total-share-tokens (- total-shares share-amount))
      
      ;; Update provider record
      (map-set liquidity-providers
        { provider: tx-sender }
        (merge provider-info 
          { 
            share-tokens: (- (get share-tokens provider-info) share-amount),
            amount-deposited: (if (is-eq share-amount (get share-tokens provider-info))
                                u0
                                (get amount-deposited provider-info))
          }
        )
      )
      
      (ok withdrawal-amount)
    )
  )
)

;; Oracle function to update stablecoin prices (only contract owner)
(define-public (update-price (stablecoin (string-ascii 10)) (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (and (> new-price u0) (<= new-price u15000)) err-invalid-amount) ;; Price between $0 and $1.50
    
    (map-set stablecoin-prices
      { stablecoin: stablecoin }
      { price: new-price, last-updated: block-height }
    )
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-user-policies (user principal))
  (map-get? user-policies { user: user })
)

(define-read-only (get-stablecoin-price (stablecoin (string-ascii 10)))
  (default-to u10000 
    (get price (map-get? stablecoin-prices { stablecoin: stablecoin }))
  )
)

(define-read-only (get-pool-info)
  {
    balance: (var-get pool-balance),
    total-shares: (var-get total-share-tokens),
    premium-rate: (var-get premium-rate)
  }
)

(define-read-only (get-provider-info (provider principal))
  (map-get? liquidity-providers { provider: provider })
)

;; Private functions

(define-private (calculate-premium (coverage-amount uint) (duration-blocks uint))
  (let (
    (base-premium (/ (* coverage-amount (var-get premium-rate)) u10000))
    (duration-ratio (/ duration-blocks u1008)) ;; ~1 week blocks
    (duration-multiplier (if (> duration-ratio u0) duration-ratio u1))
  )
    (* base-premium duration-multiplier)
  )
)

(define-private (calculate-payout (policy { holder: principal, stablecoin: (string-ascii 10), coverage-amount: uint, premium-paid: uint, start-block: uint, end-block: uint, depeg-threshold: uint, claimed: bool }) (current-price uint))
  (let (
    (target-price u10000) ;; $1.00 in basis points
    (threshold-price (- target-price (get depeg-threshold policy)))
    (max-coverage (get coverage-amount policy))
  )
    (if (<= current-price threshold-price)
      ;; Full payout if at or below threshold
      max-coverage
      ;; Proportional payout between threshold and target
      (let ((depeg-severity (- threshold-price current-price)))
        (let ((calculated-payout (/ (* max-coverage depeg-severity) (get depeg-threshold policy))))
          (if (< calculated-payout max-coverage) calculated-payout max-coverage)
        )
      )
    )
  )
)