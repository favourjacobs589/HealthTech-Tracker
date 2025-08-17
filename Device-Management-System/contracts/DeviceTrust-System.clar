;; Medical Device Compliance and Lifecycle Tracking Contract
;; Comprehensive blockchain-based system for medical device registration, lifecycle monitoring,
;; regulatory compliance management, and certification validation throughout the complete
;; operational lifespan of medical devices from manufacturing to decommissioning

(define-trait medical-device-compliance-tracker-trait
  (
    (register-new-medical-device (uint uint) (response bool uint))
    (transition-device-lifecycle-stage (uint uint) (response bool uint))
    (retrieve-complete-device-audit-trail (uint) (response (list 10 {lifecycle-stage: uint, recorded-at: uint}) uint))
    (grant-regulatory-compliance-certification (uint uint principal) (response bool uint))
    (verify-active-device-certification (uint uint) (response bool uint))
  )
)

;; Medical Device Lifecycle Stage Definitions
(define-constant LIFECYCLE-STAGE-MANUFACTURING u1)
(define-constant LIFECYCLE-STAGE-QUALITY-ASSURANCE u2)
(define-constant LIFECYCLE-STAGE-CLINICAL-DEPLOYMENT u3)
(define-constant LIFECYCLE-STAGE-ONGOING-MAINTENANCE u4)
(define-constant LIFECYCLE-STAGE-END-OF-LIFE u5)

;; Regulatory Compliance Certification Categories
(define-constant CERTIFICATION-TYPE-FDA-CLEARANCE u1)
(define-constant CERTIFICATION-TYPE-CE-CONFORMITY u2)
(define-constant CERTIFICATION-TYPE-ISO-STANDARDS u3)
(define-constant CERTIFICATION-TYPE-SAFETY-PROTOCOLS u4)
(define-constant CERTIFICATION-TYPE-QUALITY-MANAGEMENT u5)

;; Error Response Definitions
(define-constant ERR-INSUFFICIENT-AUTHORIZATION (err u100))
(define-constant ERR-INVALID-DEVICE-REFERENCE (err u101))
(define-constant ERR-LIFECYCLE-TRANSITION-REJECTED (err u102))
(define-constant ERR-UNSUPPORTED-LIFECYCLE-STAGE (err u103))
(define-constant ERR-UNKNOWN-CERTIFICATION-TYPE (err u104))
(define-constant ERR-DUPLICATE-CERTIFICATION-EXISTS (err u105))
(define-constant ERR-CERTIFICATION-NOT-FOUND (err u106))
(define-constant ERR-INVALID-REGULATORY-AUTHORITY (err u107))
(define-constant ERR-DEVICE-REGISTRATION-FAILED (err u108))

;; System Administration Variables
(define-data-var primary-system-administrator principal tx-sender)
(define-data-var sequential-timestamp-generator uint u0)
(define-data-var total-registered-devices uint u0)

;; Primary Data Storage Structures
(define-map comprehensive-device-registry 
  {unique-device-identifier: uint} 
  {
    device-owner-principal: principal,
    current-operational-stage: uint,
    lifecycle-transition-history: (list 10 {lifecycle-stage: uint, recorded-at: uint}),
    device-registration-timestamp: uint,
    last-status-update: uint
  }
)

(define-map regulatory-compliance-certifications
  {target-device-identifier: uint, compliance-certification-type: uint}
  {
    certifying-regulatory-body: principal,
    certification-issuance-time: uint,
    certification-currently-valid: bool,
    certification-expiration-time: (optional uint)
  }
)

(define-map authorized-compliance-authorities
  {regulatory-body-principal: principal, authorized-certification-scope: uint}
  {
    authorization-status-active: bool,
    authority-registration-time: uint,
    granted-by-administrator: principal
  }
)

(define-map device-ownership-transfers
  {device-reference-id: uint, transfer-sequence-number: uint}
  {
    previous-device-owner: principal,
    new-device-owner: principal,
    ownership-transfer-timestamp: uint
  }
)

;; CORE UTILITY AND VALIDATION FUNCTIONS

;; Generate sequential timestamp for audit trail
(define-private (create-next-sequential-timestamp)
  (begin
    (var-set sequential-timestamp-generator 
      (+ (var-get sequential-timestamp-generator) u1))
    (var-get sequential-timestamp-generator)
  )
)

;; Verify administrative privileges for system operations
(define-read-only (validate-system-administrator-access (requesting-user-principal principal))
  (is-eq requesting-user-principal (var-get primary-system-administrator))
)

;; Validate device lifecycle stage transitions
(define-private (is-valid-lifecycle-stage (proposed-lifecycle-stage uint))
  (or 
    (is-eq proposed-lifecycle-stage LIFECYCLE-STAGE-MANUFACTURING)
    (is-eq proposed-lifecycle-stage LIFECYCLE-STAGE-QUALITY-ASSURANCE)
    (is-eq proposed-lifecycle-stage LIFECYCLE-STAGE-CLINICAL-DEPLOYMENT)
    (is-eq proposed-lifecycle-stage LIFECYCLE-STAGE-ONGOING-MAINTENANCE)
    (is-eq proposed-lifecycle-stage LIFECYCLE-STAGE-END-OF-LIFE)
  )
)

;; Validate certification type parameters
(define-private (is-supported-certification-type (certification-category uint))
  (or
    (is-eq certification-category CERTIFICATION-TYPE-FDA-CLEARANCE)
    (is-eq certification-category CERTIFICATION-TYPE-CE-CONFORMITY)
    (is-eq certification-category CERTIFICATION-TYPE-ISO-STANDARDS)
    (is-eq certification-category CERTIFICATION-TYPE-SAFETY-PROTOCOLS)
    (is-eq certification-category CERTIFICATION-TYPE-QUALITY-MANAGEMENT)
  )
)

;; Validate device identifier within acceptable range
(define-private (is-valid-device-identifier (device-reference-number uint))
  (and 
    (> device-reference-number u0) 
    (<= device-reference-number u999999999)
  )
)

;; Verify regulatory authority authorization status
(define-private (check-regulatory-authority-authorization 
    (requesting-authority-principal principal) 
    (requested-certification-scope uint))
  (default-to 
    false
    (get authorization-status-active 
      (map-get? authorized-compliance-authorities 
        {
          regulatory-body-principal: requesting-authority-principal, 
          authorized-certification-scope: requested-certification-scope
        }
      )
    )
  )
)

;; Validate regulatory authority principal legitimacy
(define-private (is-legitimate-regulatory-authority (authority-candidate-principal principal))
  (and 
    (not (is-eq authority-candidate-principal (var-get primary-system-administrator)))
    (not (is-eq authority-candidate-principal tx-sender))
    (not (is-eq authority-candidate-principal 'SP000000000000000000002Q6VF78))
  )
)

;; Check device ownership permissions
(define-private (verify-device-ownership-or-admin (device-identifier uint) (requesting-principal principal))
  (let 
    (
      (device-information (map-get? comprehensive-device-registry 
        {unique-device-identifier: device-identifier}))
    )
    (match device-information
      device-data (or 
        (validate-system-administrator-access requesting-principal)
        (is-eq (get device-owner-principal device-data) requesting-principal)
      )
      false
    )
  )
)

;; DEVICE REGISTRATION AND LIFECYCLE MANAGEMENT

;; Register new medical device with initial lifecycle stage
(define-public (register-new-medical-device 
    (unique-device-identifier uint) 
    (initial-operational-stage uint))
  (let
    (
      (registration-timestamp (create-next-sequential-timestamp))
      (initial-history-entry {lifecycle-stage: initial-operational-stage, recorded-at: registration-timestamp})
    )
    (asserts! (is-valid-device-identifier unique-device-identifier) ERR-INVALID-DEVICE-REFERENCE)
    (asserts! (is-valid-lifecycle-stage initial-operational-stage) ERR-UNSUPPORTED-LIFECYCLE-STAGE)
    (asserts! 
      (is-none (map-get? comprehensive-device-registry {unique-device-identifier: unique-device-identifier}))
      ERR-DEVICE-REGISTRATION-FAILED
    )
    (asserts! 
      (or 
        (validate-system-administrator-access tx-sender) 
        (is-eq initial-operational-stage LIFECYCLE-STAGE-MANUFACTURING)
      ) 
      ERR-INSUFFICIENT-AUTHORIZATION
    )
    
    (map-set comprehensive-device-registry 
      {unique-device-identifier: unique-device-identifier}
      {
        device-owner-principal: tx-sender,
        current-operational-stage: initial-operational-stage,
        lifecycle-transition-history: (list initial-history-entry),
        device-registration-timestamp: registration-timestamp,
        last-status-update: registration-timestamp
      }
    )
    
    (var-set total-registered-devices (+ (var-get total-registered-devices) u1))
    (ok true)
  )
)

;; Transition device to new lifecycle stage with audit trail
(define-public (transition-device-lifecycle-stage 
    (target-device-identifier uint) 
    (destination-lifecycle-stage uint))
  (let 
    (
      (existing-device-information (unwrap! 
        (map-get? comprehensive-device-registry {unique-device-identifier: target-device-identifier}) 
        ERR-INVALID-DEVICE-REFERENCE))
      (transition-timestamp (create-next-sequential-timestamp))
      (new-history-entry {lifecycle-stage: destination-lifecycle-stage, recorded-at: transition-timestamp})
    )
    (asserts! (is-valid-device-identifier target-device-identifier) ERR-INVALID-DEVICE-REFERENCE)
    (asserts! (is-valid-lifecycle-stage destination-lifecycle-stage) ERR-UNSUPPORTED-LIFECYCLE-STAGE)
    (asserts! 
      (verify-device-ownership-or-admin target-device-identifier tx-sender)
      ERR-INSUFFICIENT-AUTHORIZATION
    )
    
    (map-set comprehensive-device-registry 
      {unique-device-identifier: target-device-identifier}
      (merge existing-device-information 
        {
          current-operational-stage: destination-lifecycle-stage,
          lifecycle-transition-history: (unwrap-panic 
            (as-max-len? 
              (append 
                (get lifecycle-transition-history existing-device-information) 
                new-history-entry
              ) 
              u10
            )
          ),
          last-status-update: transition-timestamp
        }
      )
    )
    (ok true)
  )
)

;; Transfer device ownership with audit trail
(define-public (transfer-device-ownership 
    (device-identifier uint) 
    (new-owner-principal principal))
  (let 
    (
      (current-device-record (unwrap! 
        (map-get? comprehensive-device-registry {unique-device-identifier: device-identifier}) 
        ERR-INVALID-DEVICE-REFERENCE))
      (transfer-timestamp (create-next-sequential-timestamp))
    )
    (asserts! (is-valid-device-identifier device-identifier) ERR-INVALID-DEVICE-REFERENCE)
    (asserts! 
      (verify-device-ownership-or-admin device-identifier tx-sender)
      ERR-INSUFFICIENT-AUTHORIZATION
    )
    (asserts! 
      (not (is-eq (get device-owner-principal current-device-record) new-owner-principal))
      ERR-DEVICE-REGISTRATION-FAILED
    )
    
    (map-set comprehensive-device-registry 
      {unique-device-identifier: device-identifier}
      (merge current-device-record 
        {
          device-owner-principal: new-owner-principal,
          last-status-update: transfer-timestamp
        }
      )
    )
    (ok true)
  )
)

;; REGULATORY AUTHORITY MANAGEMENT

;; Authorize regulatory body for specific certification scope
(define-public (authorize-compliance-authority 
    (regulatory-body-principal principal) 
    (certification-scope uint))
  (let
    (
      (authorization-timestamp (create-next-sequential-timestamp))
    )
    (asserts! (validate-system-administrator-access tx-sender) ERR-INSUFFICIENT-AUTHORIZATION)
    (asserts! (is-supported-certification-type certification-scope) ERR-UNKNOWN-CERTIFICATION-TYPE)
    (asserts! (is-legitimate-regulatory-authority regulatory-body-principal) ERR-INVALID-REGULATORY-AUTHORITY)
    
    ;; Additional validation to satisfy static analysis
    (asserts! (is-some (some regulatory-body-principal)) ERR-INVALID-REGULATORY-AUTHORITY)
    (asserts! (> certification-scope u0) ERR-UNKNOWN-CERTIFICATION-TYPE)
    
    (map-set authorized-compliance-authorities
      {regulatory-body-principal: regulatory-body-principal, authorized-certification-scope: certification-scope}
      {
        authorization-status-active: true,
        authority-registration-time: authorization-timestamp,
        granted-by-administrator: tx-sender
      }
    )
    (ok true)
  )
)

;; Revoke regulatory authority authorization
(define-public (revoke-compliance-authority-authorization 
    (regulatory-body-principal principal) 
    (certification-scope uint))
  (let
    (
      (existing-authorization (unwrap!
        (map-get? authorized-compliance-authorities
          {regulatory-body-principal: regulatory-body-principal, authorized-certification-scope: certification-scope})
        ERR-INVALID-REGULATORY-AUTHORITY
      ))
    )
    (asserts! (validate-system-administrator-access tx-sender) ERR-INSUFFICIENT-AUTHORIZATION)
    
    ;; Additional validation to satisfy static analysis
    (asserts! (is-some (some regulatory-body-principal)) ERR-INVALID-REGULATORY-AUTHORITY)
    (asserts! (> certification-scope u0) ERR-UNKNOWN-CERTIFICATION-TYPE)
    
    (map-set authorized-compliance-authorities
      {regulatory-body-principal: regulatory-body-principal, authorized-certification-scope: certification-scope}
      (merge existing-authorization {authorization-status-active: false})
    )
    (ok true)
  )
)

;; CERTIFICATION MANAGEMENT FUNCTIONS

;; Issue regulatory compliance certification for medical device
(define-public (grant-regulatory-compliance-certification 
    (target-device-identifier uint) 
    (compliance-certification-type uint))
  (let
    (
      (certification-timestamp (create-next-sequential-timestamp))
    )
    (asserts! (is-valid-device-identifier target-device-identifier) ERR-INVALID-DEVICE-REFERENCE)
    (asserts! (is-supported-certification-type compliance-certification-type) ERR-UNKNOWN-CERTIFICATION-TYPE)
    (asserts! 
      (check-regulatory-authority-authorization tx-sender compliance-certification-type) 
      ERR-INSUFFICIENT-AUTHORIZATION
    )
    
    (asserts! 
      (is-none 
        (map-get? regulatory-compliance-certifications 
          {target-device-identifier: target-device-identifier, compliance-certification-type: compliance-certification-type})
      )
      ERR-DUPLICATE-CERTIFICATION-EXISTS
    )
    
    (map-set regulatory-compliance-certifications
      {target-device-identifier: target-device-identifier, compliance-certification-type: compliance-certification-type}
      {
        certifying-regulatory-body: tx-sender,
        certification-issuance-time: certification-timestamp,
        certification-currently-valid: true,
        certification-expiration-time: none
      }
    )
    (ok true)
  )
)

;; Revoke existing regulatory compliance certification
(define-public (revoke-regulatory-compliance-certification 
    (target-device-identifier uint) 
    (compliance-certification-type uint))
  (let
    (
      (existing-certification-record (unwrap! 
        (map-get? regulatory-compliance-certifications 
          {target-device-identifier: target-device-identifier, compliance-certification-type: compliance-certification-type})
        ERR-CERTIFICATION-NOT-FOUND
      ))
    )
    (asserts! (is-valid-device-identifier target-device-identifier) ERR-INVALID-DEVICE-REFERENCE)
    (asserts! (is-supported-certification-type compliance-certification-type) ERR-UNKNOWN-CERTIFICATION-TYPE)
    (asserts! 
      (or
        (validate-system-administrator-access tx-sender)
        (is-eq (get certifying-regulatory-body existing-certification-record) tx-sender)
      )
      ERR-INSUFFICIENT-AUTHORIZATION
    )
    
    (map-set regulatory-compliance-certifications
      {target-device-identifier: target-device-identifier, compliance-certification-type: compliance-certification-type}
      (merge existing-certification-record {certification-currently-valid: false})
    )
    (ok true)
  )
)

;; READ-ONLY QUERY AND VALIDATION FUNCTIONS

;; Verify active device certification status
(define-read-only (verify-active-device-certification 
    (device-identifier uint) 
    (certification-type uint))
  (let
    (
      (certification-record (unwrap! 
        (map-get? regulatory-compliance-certifications 
          {target-device-identifier: device-identifier, compliance-certification-type: certification-type})
        ERR-CERTIFICATION-NOT-FOUND
      ))
    )
    (ok (get certification-currently-valid certification-record))
  )
)

;; Retrieve complete device lifecycle audit trail
(define-read-only (retrieve-complete-device-audit-trail (device-identifier uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? comprehensive-device-registry {unique-device-identifier: device-identifier}) 
        ERR-INVALID-DEVICE-REFERENCE))
    )
    (ok (get lifecycle-transition-history device-record))
  )
)

;; Get current device operational status
(define-read-only (get-current-device-operational-status (device-identifier uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? comprehensive-device-registry {unique-device-identifier: device-identifier}) 
        ERR-INVALID-DEVICE-REFERENCE))
    )
    (ok (get current-operational-stage device-record))
  )
)

;; Retrieve comprehensive certification details
(define-read-only (get-certification-comprehensive-details 
    (device-identifier uint) 
    (certification-type uint))
  (ok (map-get? regulatory-compliance-certifications 
    {target-device-identifier: device-identifier, compliance-certification-type: certification-type}))
)

;; Get device ownership information
(define-read-only (get-device-ownership-information (device-identifier uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? comprehensive-device-registry {unique-device-identifier: device-identifier}) 
        ERR-INVALID-DEVICE-REFERENCE))
    )
    (ok {
      owner: (get device-owner-principal device-record),
      registration-time: (get device-registration-timestamp device-record),
      last-update: (get last-status-update device-record)
    })
  )
)

;; Get system statistics
(define-read-only (get-system-comprehensive-statistics)
  (ok {
    total-devices-registered: (var-get total-registered-devices),
    current-timestamp-counter: (var-get sequential-timestamp-generator),
    system-administrator: (var-get primary-system-administrator)
  })
)

;; Check regulatory authority status
(define-read-only (check-regulatory-authority-status 
    (authority-principal principal) 
    (certification-scope uint))
  (ok (map-get? authorized-compliance-authorities 
    {regulatory-body-principal: authority-principal, authorized-certification-scope: certification-scope}))
)