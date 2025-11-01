;; Relief Coordinator Smart Contract
;; Manages disaster relief operations including aid distribution, volunteer deployment, and resource allocation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-OPERATION (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-SUPPLY (err u104))
(define-constant ERR-INVALID-BENEFICIARY (err u105))
(define-constant ERR-DUPLICATE-CLAIM (err u106))
(define-constant ERR-INVALID-STATUS (err u107))

;; Data Variables
(define-data-var operation-id-nonce uint u0)
(define-data-var supply-id-nonce uint u0)
(define-data-var volunteer-id-nonce uint u0)
(define-data-var beneficiary-id-nonce uint u0)
(define-data-var donation-id-nonce uint u0)

;; Data Maps

;; Relief Operations
(define-map relief-operations
    { operation-id: uint }
    {
        coordinator: principal,
        disaster-type: (string-ascii 50),
        location: (string-ascii 100),
        start-date: uint,
        status: (string-ascii 20),
        total-donations: uint,
        total-supplies: uint,
        total-volunteers: uint,
        beneficiaries-served: uint
    }
)

;; Organizations
(define-map authorized-organizations
    { org-address: principal }
    {
        name: (string-ascii 100),
        org-type: (string-ascii 50),
        registered-date: uint,
        is-active: bool
    }
)

;; Supply Inventory
(define-map supplies
    { supply-id: uint }
    {
        operation-id: uint,
        supply-type: (string-ascii 50),
        quantity: uint,
        unit: (string-ascii 20),
        source: principal,
        location: (string-ascii 100),
        status: (string-ascii 20),
        added-date: uint,
        expiration-date: uint
    }
)

;; Volunteers
(define-map volunteers
    { volunteer-id: uint }
    {
        volunteer-address: principal,
        operation-id: uint,
        skills: (string-ascii 200),
        assigned-task: (string-ascii 100),
        status: (string-ascii 20),
        hours-contributed: uint,
        registration-date: uint
    }
)

;; Beneficiaries
(define-map beneficiaries
    { beneficiary-id: uint }
    {
        beneficiary-address: principal,
        operation-id: uint,
        family-size: uint,
        needs: (string-ascii 200),
        verification-status: (string-ascii 20),
        aid-received: uint,
        registration-date: uint
    }
)

;; Donations
(define-map donations
    { donation-id: uint }
    {
        donor: principal,
        operation-id: uint,
        amount: uint,
        donation-type: (string-ascii 50),
        allocated: bool,
        donation-date: uint
    }
)

;; Aid Distribution Records
(define-map aid-distributions
    { beneficiary-id: uint, supply-id: uint }
    {
        quantity-received: uint,
        distribution-date: uint,
        distributor: principal
    }
)

;; Read-only functions

(define-read-only (get-operation (operation-id uint))
    (map-get? relief-operations { operation-id: operation-id })
)

(define-read-only (get-supply (supply-id uint))
    (map-get? supplies { supply-id: supply-id })
)

(define-read-only (get-volunteer (volunteer-id uint))
    (map-get? volunteers { volunteer-id: volunteer-id })
)

(define-read-only (get-beneficiary (beneficiary-id uint))
    (map-get? beneficiaries { beneficiary-id: beneficiary-id })
)

(define-read-only (get-donation (donation-id uint))
    (map-get? donations { donation-id: donation-id })
)

(define-read-only (is-authorized-organization (org-address principal))
    (match (map-get? authorized-organizations { org-address: org-address })
        org (get is-active org)
        false
    )
)

(define-read-only (get-aid-distribution (beneficiary-id uint) (supply-id uint))
    (map-get? aid-distributions { beneficiary-id: beneficiary-id, supply-id: supply-id })
)

(define-read-only (get-operation-id-nonce)
    (var-get operation-id-nonce)
)

(define-read-only (get-supply-id-nonce)
    (var-get supply-id-nonce)
)

;; Public functions

;; Initialize a new relief operation
(define-public (initialize-relief-operation (disaster-type (string-ascii 50)) (location (string-ascii 100)))
    (let
        (
            (new-operation-id (+ (var-get operation-id-nonce) u1))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set relief-operations
            { operation-id: new-operation-id }
            {
                coordinator: tx-sender,
                disaster-type: disaster-type,
                location: location,
                start-date: block-height,
                status: "active",
                total-donations: u0,
                total-supplies: u0,
                total-volunteers: u0,
                beneficiaries-served: u0
            }
        )
        (var-set operation-id-nonce new-operation-id)
        (ok new-operation-id)
    )
)

;; Register an authorized organization
(define-public (register-organization (org-address principal) (name (string-ascii 100)) (org-type (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? authorized-organizations { org-address: org-address })) ERR-ALREADY-EXISTS)
        (ok (map-set authorized-organizations
            { org-address: org-address }
            {
                name: name,
                org-type: org-type,
                registered-date: block-height,
                is-active: true
            }
        ))
    )
)

;; Add supply inventory
(define-public (add-supply-inventory 
    (operation-id uint)
    (supply-type (string-ascii 50))
    (quantity uint)
    (unit (string-ascii 20))
    (location (string-ascii 100))
    (expiration-date uint)
)
    (let
        (
            (new-supply-id (+ (var-get supply-id-nonce) u1))
            (operation (unwrap! (map-get? relief-operations { operation-id: operation-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (map-set supplies
            { supply-id: new-supply-id }
            {
                operation-id: operation-id,
                supply-type: supply-type,
                quantity: quantity,
                unit: unit,
                source: tx-sender,
                location: location,
                status: "available",
                added-date: block-height,
                expiration-date: expiration-date
            }
        )
        (map-set relief-operations
            { operation-id: operation-id }
            (merge operation { total-supplies: (+ (get total-supplies operation) quantity) })
        )
        (var-set supply-id-nonce new-supply-id)
        (ok new-supply-id)
    )
)

;; Register a volunteer
(define-public (register-volunteer
    (operation-id uint)
    (skills (string-ascii 200))
)
    (let
        (
            (new-volunteer-id (+ (var-get volunteer-id-nonce) u1))
            (operation (unwrap! (map-get? relief-operations { operation-id: operation-id }) ERR-NOT-FOUND))
        )
        (map-set volunteers
            { volunteer-id: new-volunteer-id }
            {
                volunteer-address: tx-sender,
                operation-id: operation-id,
                skills: skills,
                assigned-task: "",
                status: "registered",
                hours-contributed: u0,
                registration-date: block-height
            }
        )
        (map-set relief-operations
            { operation-id: operation-id }
            (merge operation { total-volunteers: (+ (get total-volunteers operation) u1) })
        )
        (var-set volunteer-id-nonce new-volunteer-id)
        (ok new-volunteer-id)
    )
)

;; Assign volunteer to task
(define-public (assign-volunteer-task (volunteer-id uint) (task (string-ascii 100)))
    (let
        (
            (volunteer (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (ok (map-set volunteers
            { volunteer-id: volunteer-id }
            (merge volunteer { assigned-task: task, status: "assigned" })
        ))
    )
)

;; Record volunteer hours
(define-public (record-volunteer-hours (volunteer-id uint) (hours uint))
    (let
        (
            (volunteer (unwrap! (map-get? volunteers { volunteer-id: volunteer-id }) ERR-NOT-FOUND))
        )
        (asserts! (or (is-eq tx-sender (get volunteer-address volunteer)) (is-authorized-organization tx-sender)) ERR-NOT-AUTHORIZED)
        (ok (map-set volunteers
            { volunteer-id: volunteer-id }
            (merge volunteer { hours-contributed: (+ (get hours-contributed volunteer) hours) })
        ))
    )
)

;; Record a donation
(define-public (record-donation
    (operation-id uint)
    (amount uint)
    (donation-type (string-ascii 50))
)
    (let
        (
            (new-donation-id (+ (var-get donation-id-nonce) u1))
            (operation (unwrap! (map-get? relief-operations { operation-id: operation-id }) ERR-NOT-FOUND))
        )
        (map-set donations
            { donation-id: new-donation-id }
            {
                donor: tx-sender,
                operation-id: operation-id,
                amount: amount,
                donation-type: donation-type,
                allocated: false,
                donation-date: block-height
            }
        )
        (map-set relief-operations
            { operation-id: operation-id }
            (merge operation { total-donations: (+ (get total-donations operation) amount) })
        )
        (var-set donation-id-nonce new-donation-id)
        (ok new-donation-id)
    )
)

;; Register a beneficiary
(define-public (register-beneficiary
    (beneficiary-address principal)
    (operation-id uint)
    (family-size uint)
    (needs (string-ascii 200))
)
    (let
        (
            (new-beneficiary-id (+ (var-get beneficiary-id-nonce) u1))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? relief-operations { operation-id: operation-id })) ERR-NOT-FOUND)
        (map-set beneficiaries
            { beneficiary-id: new-beneficiary-id }
            {
                beneficiary-address: beneficiary-address,
                operation-id: operation-id,
                family-size: family-size,
                needs: needs,
                verification-status: "pending",
                aid-received: u0,
                registration-date: block-height
            }
        )
        (var-set beneficiary-id-nonce new-beneficiary-id)
        (ok new-beneficiary-id)
    )
)

;; Verify beneficiary eligibility
(define-public (verify-beneficiary (beneficiary-id uint))
    (let
        (
            (beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (ok (map-set beneficiaries
            { beneficiary-id: beneficiary-id }
            (merge beneficiary { verification-status: "verified" })
        ))
    )
)

;; Distribute supplies to beneficiary
(define-public (distribute-supplies
    (beneficiary-id uint)
    (supply-id uint)
    (quantity uint)
)
    (let
        (
            (beneficiary (unwrap! (map-get? beneficiaries { beneficiary-id: beneficiary-id }) ERR-NOT-FOUND))
            (supply (unwrap! (map-get? supplies { supply-id: supply-id }) ERR-NOT-FOUND))
            (operation (unwrap! (map-get? relief-operations { operation-id: (get operation-id beneficiary) }) ERR-NOT-FOUND))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get verification-status beneficiary) "verified") ERR-INVALID-BENEFICIARY)
        (asserts! (>= (get quantity supply) quantity) ERR-INSUFFICIENT-SUPPLY)
        (asserts! (is-none (map-get? aid-distributions { beneficiary-id: beneficiary-id, supply-id: supply-id })) ERR-DUPLICATE-CLAIM)
        
        ;; Record distribution
        (map-set aid-distributions
            { beneficiary-id: beneficiary-id, supply-id: supply-id }
            {
                quantity-received: quantity,
                distribution-date: block-height,
                distributor: tx-sender
            }
        )
        
        ;; Update supply quantity
        (map-set supplies
            { supply-id: supply-id }
            (merge supply { quantity: (- (get quantity supply) quantity) })
        )
        
        ;; Update beneficiary aid received
        (map-set beneficiaries
            { beneficiary-id: beneficiary-id }
            (merge beneficiary { aid-received: (+ (get aid-received beneficiary) quantity) })
        )
        
        ;; Update operation beneficiaries served
        (map-set relief-operations
            { operation-id: (get operation-id beneficiary) }
            (merge operation { beneficiaries-served: (+ (get beneficiaries-served operation) u1) })
        )
        
        (ok true)
    )
)

;; Update operation status
(define-public (update-operation-status (operation-id uint) (new-status (string-ascii 20)))
    (let
        (
            (operation (unwrap! (map-get? relief-operations { operation-id: operation-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set relief-operations
            { operation-id: operation-id }
            (merge operation { status: new-status })
        ))
    )
)

;; Allocate donation funds
(define-public (allocate-donation-funds (donation-id uint))
    (let
        (
            (donation (unwrap! (map-get? donations { donation-id: donation-id }) ERR-NOT-FOUND))
        )
        (asserts! (is-authorized-organization tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (not (get allocated donation)) ERR-INVALID-STATUS)
        (ok (map-set donations
            { donation-id: donation-id }
            (merge donation { allocated: true })
        ))
    )
)


;; title: relief-coordinator
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

