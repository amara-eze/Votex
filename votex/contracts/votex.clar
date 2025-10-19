;; Simplified Decentralized Autonomous Organization (DAO)
;; Core functionality with membership management, proposals, and voting

;; Define SIP-010 fungible token trait
(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    ;; the human readable name of the token
    (get-name () (response (string-ascii 32) uint))
    ;; the ticker symbol, or empty if none
    (get-symbol () (response (string-ascii 32) uint))
    ;; the number of decimals used, e.g. 6 would mean 1_000_000 represents 1 token
    (get-decimals () (response uint uint))
    ;; the balance of the passed principal
    (get-balance (principal) (response uint uint))
    ;; the current total supply (which does not need to be a constant)
    (get-total-supply () (response uint uint))
    ;; an optional URI that represents metadata of this token
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Error constants
(define-constant ERR-MISSING (err u404))
(define-constant ERR-FORBIDDEN (err u401))
(define-constant ERR-BAD-PARAMS (err u400))
(define-constant ERR-LOW-BALANCE (err u402))
(define-constant ERR-INACTIVE (err u403))
(define-constant ERR-VOTE-CLOSED (err u405))
(define-constant ERR-DUPLICATE-VOTE (err u406))

;; DAO basic information
(define-map dao-registry
  { dao-id: uint }
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    creator: principal,
    created-at: uint,
    governance-token: principal,
    membership-threshold: uint,
    active: bool
  }
)

;; DAO governance settings
(define-map settings-registry
  { dao-id: uint }
  {
    voting-period: uint,
    voting-quorum: uint,
    majority-threshold: uint,
    proposal-threshold: uint
  }
)

;; DAO members
(define-map member-registry
  { dao-id: uint, member: principal }
  {
    joined-at: uint,
    active: bool,
    is-admin: bool,
    voting-power: uint
  }
)

;; Proposals
(define-map proposal-registry
  { dao-id: uint, proposal-id: uint }
  {
    title: (string-utf8 128),
    description: (string-utf8 512),
    proposer: principal,
    created-at: uint,
    voting-ends-at: uint,
    status: (string-ascii 16),
    votes-for: uint,
    votes-against: uint,
    total-votes: uint
  }
)

;; Votes cast
(define-map vote-registry
  { dao-id: uint, proposal-id: uint, voter: principal }
  {
    vote-for: bool,
    voting-power: uint,
    timestamp: uint
  }
)

;; Treasury balances
(define-map treasury-registry
  { dao-id: uint }
  {
    stx-balance: uint,
    last-updated: uint
  }
)

;; Counters
(define-data-var dao-counter uint u1)
(define-map proposal-counter { dao-id: uint } { id: uint })

;; Helper functions
(define-private (validate-dao-id (dao-id uint))
  (is-some (map-get? dao-registry { dao-id: dao-id }))
)

(define-private (check-active (dao-id uint))
  (match (map-get? dao-registry { dao-id: dao-id })
    dao-data (get active dao-data)
    false
  )
)

(define-private (check-member (dao-id uint) (user principal))
  (match (map-get? member-registry { dao-id: dao-id, member: user })
    member-data (get active member-data)
    false
  )
)

(define-private (check-admin (dao-id uint) (user principal))
  (match (map-get? member-registry { dao-id: dao-id, member: user })
    member-data (and (get active member-data) (get is-admin member-data))
    false
  )
)

;; Create a new DAO
(define-public (new-dao
                (name (string-utf8 64))
                (description (string-utf8 256))
                (governance-token principal)
                (membership-threshold uint))
  (let ((dao-id (var-get dao-counter)))
    
    ;; Validate parameters
    (asserts! (> membership-threshold u0) ERR-BAD-PARAMS)
    (asserts! (> (len name) u0) ERR-BAD-PARAMS)
    
    ;; Create DAO
    (map-set dao-registry
      { dao-id: dao-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        created-at: block-height,
        governance-token: governance-token,
        membership-threshold: membership-threshold,
        active: true
      }
    )
    
    ;; Set default governance settings
    (map-set settings-registry
      { dao-id: dao-id }
      {
        voting-period: u1440,    ;; ~10 days
        voting-quorum: u2000,    ;; 20%
        majority-threshold: u5000, ;; 50%
        proposal-threshold: membership-threshold
      }
    )
    
    ;; Initialize treasury
    (map-set treasury-registry
      { dao-id: dao-id }
      {
        stx-balance: u0,
        last-updated: block-height
      }
    )
    
    ;; Add creator as admin member
    (map-set member-registry
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: true,
        voting-power: u0
      }
    )
    
    ;; Initialize proposal counter
    (map-set proposal-counter { dao-id: dao-id } { id: u0 })
    
    ;; Increment DAO counter
    (var-set dao-counter (+ dao-id u1))
    
    (ok dao-id)
  )
)

;; Join DAO as member (simplified without token balance check)
(define-public (join-simple (dao-id uint))
  (let ((dao-data (unwrap! (map-get? dao-registry { dao-id: dao-id }) ERR-MISSING)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-INACTIVE)
    (asserts! (not (check-member dao-id tx-sender)) ERR-BAD-PARAMS)
    
    ;; Add member with basic voting power
    (map-set member-registry
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: false,
        voting-power: u1000000 ;; Default voting power
      }
    )
    
    (ok true)
  )
)

;; Join DAO with token balance check
(define-public (join-with-token (dao-id uint) (token-balance uint))
  (let ((dao-data (unwrap! (map-get? dao-registry { dao-id: dao-id }) ERR-MISSING)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-INACTIVE)
    (asserts! (>= token-balance (get membership-threshold dao-data)) ERR-LOW-BALANCE)
    (asserts! (not (check-member dao-id tx-sender)) ERR-BAD-PARAMS)
    
    ;; Add member
    (map-set member-registry
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: false,
        voting-power: token-balance
      }
    )
    
    (ok true)
  )
)

;; Update governance settings (admin only)
(define-public (update-settings
                (dao-id uint)
                (voting-period uint)
                (voting-quorum uint)
                (majority-threshold uint)
                (proposal-threshold uint))
  (begin
    ;; Validate
    (asserts! (validate-dao-id dao-id) ERR-MISSING)
    (asserts! (check-active dao-id) ERR-INACTIVE)
    (asserts! (check-admin dao-id tx-sender) ERR-FORBIDDEN)
    (asserts! (and (> voting-period u0) (<= voting-quorum u10000) (<= majority-threshold u10000)) ERR-BAD-PARAMS)
    
    ;; Update settings
    (map-set settings-registry
      { dao-id: dao-id }
      {
        voting-period: voting-period,
        voting-quorum: voting-quorum,
        majority-threshold: majority-threshold,
        proposal-threshold: proposal-threshold
      }
    )
    
    (ok true)
  )
)

;; Create proposal
(define-public (new-proposal
                (dao-id uint)
                (title (string-utf8 128))
                (description (string-utf8 512)))
  (let ((dao-data (unwrap! (map-get? dao-registry { dao-id: dao-id }) ERR-MISSING))
        (settings (unwrap! (map-get? settings-registry { dao-id: dao-id }) ERR-MISSING))
        (member-data (unwrap! (map-get? member-registry { dao-id: dao-id, member: tx-sender }) ERR-FORBIDDEN))
        (proposal-counter-data (unwrap! (map-get? proposal-counter { dao-id: dao-id }) ERR-MISSING))
        (proposal-id (get id proposal-counter-data)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-INACTIVE)
    (asserts! (get active member-data) ERR-FORBIDDEN)
    (asserts! (>= (get voting-power member-data) (get proposal-threshold settings)) ERR-LOW-BALANCE)
    (asserts! (> (len title) u0) ERR-BAD-PARAMS)
    
    ;; Create proposal
    (map-set proposal-registry
      { dao-id: dao-id, proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        created-at: block-height,
        voting-ends-at: (+ block-height (get voting-period settings)),
        status: "active",
        votes-for: u0,
        votes-against: u0,
        total-votes: u0
      }
    )
    
    ;; Increment proposal counter
    (map-set proposal-counter
      { dao-id: dao-id }
      { id: (+ proposal-id u1) }
    )
    
    (ok proposal-id)
  )
)

;; Vote on proposal
(define-public (cast-vote
                (dao-id uint)
                (proposal-id uint)
                (vote-for bool))
  (let ((dao-data (unwrap! (map-get? dao-registry { dao-id: dao-id }) ERR-MISSING))
        (proposal (unwrap! (map-get? proposal-registry { dao-id: dao-id, proposal-id: proposal-id }) ERR-MISSING))
        (member-data (unwrap! (map-get? member-registry { dao-id: dao-id, member: tx-sender }) ERR-FORBIDDEN))
        (voting-power (get voting-power member-data)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-INACTIVE)
    (asserts! (get active member-data) ERR-FORBIDDEN)
    (asserts! (is-eq (get status proposal) "active") ERR-BAD-PARAMS)
    (asserts! (< block-height (get voting-ends-at proposal)) ERR-VOTE-CLOSED)
    (asserts! (is-none (map-get? vote-registry { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender })) ERR-DUPLICATE-VOTE)
    (asserts! (> voting-power u0) ERR-LOW-BALANCE)
    
    ;; Record vote
    (map-set vote-registry
      { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender }
      {
        vote-for: vote-for,
        voting-power: voting-power,
        timestamp: block-height
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposal-registry
      { dao-id: dao-id, proposal-id: proposal-id }
      (merge proposal
        {
          votes-for: (if vote-for (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
          votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
          total-votes: (+ (get total-votes proposal) voting-power)
        }
      )
    )
    
    (ok true)
  )
)

;; Finalize proposal
(define-public (settle-proposal (dao-id uint) (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposal-registry { dao-id: dao-id, proposal-id: proposal-id }) ERR-MISSING))
        (settings (unwrap! (map-get? settings-registry { dao-id: dao-id }) ERR-MISSING)))
    
    ;; Validate
    (asserts! (is-eq (get status proposal) "active") ERR-BAD-PARAMS)
    (asserts! (>= block-height (get voting-ends-at proposal)) ERR-VOTE-CLOSED)
    
    ;; Calculate results
    (let ((total-supply u100000000) ;; Simplified total supply
          (quorum-met (>= (get total-votes proposal) (/ (* total-supply (get voting-quorum settings)) u10000)))
          (majority-met (>= (get votes-for proposal) (/ (* (get total-votes proposal) (get majority-threshold settings)) u10000))))
      
      ;; Update proposal status
      (map-set proposal-registry
        { dao-id: dao-id, proposal-id: proposal-id }
        (merge proposal
          {
            status: (if (and quorum-met majority-met) "passed" "rejected")
          }
        )
      )
      
      (ok (and quorum-met majority-met))
    )
  )
)

;; Add funds to treasury
(define-public (deposit-funds (dao-id uint) (amount uint))
  (let ((treasury-data (unwrap! (map-get? treasury-registry { dao-id: dao-id }) ERR-MISSING)))
    
    ;; Validate
    (asserts! (validate-dao-id dao-id) ERR-MISSING)
    (asserts! (check-active dao-id) ERR-INACTIVE)
    (asserts! (> amount u0) ERR-BAD-PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update treasury
    (map-set treasury-registry
      { dao-id: dao-id }
      {
        stx-balance: (+ (get stx-balance treasury-data) amount),
        last-updated: block-height
      }
    )
    
    (ok true)
  )
)

;; Transfer funds from treasury (admin only)
(define-public (withdraw-funds (dao-id uint) (recipient principal) (amount uint))
  (let ((treasury-data (unwrap! (map-get? treasury-registry { dao-id: dao-id }) ERR-MISSING)))
    
    ;; Validate
    (asserts! (validate-dao-id dao-id) ERR-MISSING)
    (asserts! (check-active dao-id) ERR-INACTIVE)
    (asserts! (check-admin dao-id tx-sender) ERR-FORBIDDEN)
    (asserts! (>= (get stx-balance treasury-data) amount) ERR-LOW-BALANCE)
    (asserts! (> amount u0) ERR-BAD-PARAMS)
    
    ;; Transfer STX
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update treasury
    (map-set treasury-registry
      { dao-id: dao-id }
      {
        stx-balance: (- (get stx-balance treasury-data) amount),
        last-updated: block-height
      }
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (fetch-dao (dao-id uint))
  (map-get? dao-registry { dao-id: dao-id })
)

(define-read-only (fetch-proposal (dao-id uint) (proposal-id uint))
  (map-get? proposal-registry { dao-id: dao-id, proposal-id: proposal-id })
)

(define-read-only (fetch-member (dao-id uint) (member principal))
  (map-get? member-registry { dao-id: dao-id, member: member })
)

(define-read-only (fetch-treasury (dao-id uint))
  (map-get? treasury-registry { dao-id: dao-id })
)

(define-read-only (fetch-settings (dao-id uint))
  (map-get? settings-registry { dao-id: dao-id })
)

(define-read-only (fetch-vote (dao-id uint) (proposal-id uint) (voter principal))
  (map-get? vote-registry { dao-id: dao-id, proposal-id: proposal-id, voter: voter })
)

(define-read-only (fetch-dao-counter)
  (var-get dao-counter)
)