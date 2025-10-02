;; PixelVault NFT Marketplace Smart Contract (Fixed)
;; Define constants
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-invalid-token-id (err u104))
(define-constant err-invalid-uri (err u105))
(define-constant err-invalid-royalty (err u106))
(define-constant err-invalid-principal (err u107))
(define-constant err-self-transfer (err u108))

;; Define NFT asset
(define-non-fungible-token pixelvault uint)

;; Define data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)

;; Define data maps
(define-map tokens
  { token-id: uint }
  { owner: principal, creator: principal, uri: (string-ascii 256), royalty: uint }
)

(define-map listings
  { token-id: uint }
  { price: uint, seller: principal }
)

;; Private function to check contract ownership
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Private function to validate principal
(define-private (is-valid-principal (principal-to-check principal))
  (and
    (not (is-eq principal-to-check (as-contract tx-sender)))
    (is-standard principal-to-check)
  )
)

;; Transfer contract ownership with validation
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    ;; Validate new owner is a valid principal
    (asserts! (is-valid-principal new-owner) err-invalid-principal)
    ;; Prevent transferring to self (no-op)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) err-self-transfer)
    (var-set contract-owner new-owner)
    (print { event: "contract-ownership-transferred", old-owner: tx-sender, new-owner: new-owner })
    (ok true)
  )
)

;; Get current contract owner
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; Mint new NFT
(define-public (mint (uri (string-ascii 256)) (royalty uint))
  (let
    (
      (token-id (var-get next-token-id))
    )
    (asserts! (> (len uri) u0) err-invalid-uri)
    ;; Royalty should be max 10% (1000 basis points)
    (asserts! (<= royalty u1000) err-invalid-royalty)
    (try! (nft-mint? pixelvault token-id tx-sender))
    (map-set tokens
      { token-id: token-id }
      { owner: tx-sender, creator: tx-sender, uri: uri, royalty: royalty }
    )
    (var-set next-token-id (+ token-id u1))
    (print { event: "nft-minted", token-id: token-id, creator: tx-sender, royalty: royalty })
    (ok token-id)
  )
)

;; List NFT for sale
(define-public (list-nft (token-id uint) (price uint))
  (let
    (
      (token-owner (unwrap! (nft-get-owner? pixelvault token-id) err-invalid-token-id))
    )
    (asserts! (> price u0) err-invalid-price)
    (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
    ;; Verify token exists in our map
    (asserts! (is-some (map-get? tokens { token-id: token-id })) err-invalid-token-id)
    (map-set listings
      { token-id: token-id }
      { price: price, seller: tx-sender }
    )
    (print { event: "nft-listed", token-id: token-id, price: price, seller: tx-sender })
    (ok true)
  )
)

;; Cancel NFT listing
(define-public (cancel-listing (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
    )
    (asserts! (< token-id (var-get next-token-id)) err-invalid-token-id)
    (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
    (map-delete listings { token-id: token-id })
    (print { event: "listing-cancelled", token-id: token-id, seller: tx-sender })
    (ok true)
  )
)

;; Buy NFT with improved safety
(define-public (buy-nft (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (token (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token-id))
      (creator (get creator token))
      (royalty (get royalty token))
      ;; Calculate royalty amount safely
      (royalty-amount (/ (* price royalty) u10000))
      (seller-amount (- price royalty-amount))
    )
    ;; Validate token ID
    (asserts! (< token-id (var-get next-token-id)) err-invalid-token-id)
    ;; Verify seller still owns the NFT (prevent race conditions)
    (asserts! (is-eq (unwrap! (nft-get-owner? pixelvault token-id) err-invalid-token-id) seller) err-not-token-owner)
    ;; Transfer royalty to creator
    (try! (stx-transfer? royalty-amount tx-sender creator))
    ;; Transfer payment to seller
    (try! (stx-transfer? seller-amount tx-sender seller))
    ;; Transfer NFT to buyer
    (try! (nft-transfer? pixelvault token-id seller tx-sender))
    ;; Update token ownership
    (map-set tokens
      { token-id: token-id }
      (merge token { owner: tx-sender })
    )
    ;; Remove listing
    (map-delete listings { token-id: token-id })
    (print { 
      event: "nft-sold", 
      token-id: token-id, 
      buyer: tx-sender, 
      seller: seller, 
      price: price,
      royalty-amount: royalty-amount 
    })
    (ok true)
  )
)

;; Get token details
(define-read-only (get-token-details (token-id uint))
  (ok (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token-id))
)

;; Get listing details
(define-read-only (get-listing (token-id uint))
  (ok (unwrap! (map-get? listings { token-id: token-id }) err-listing-not-found))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (get uri (unwrap! (map-get? tokens { token-id: token-id }) err-invalid-token-id)))
)

;; Get next token ID
(define-read-only (get-next-token-id)
  (ok (var-get next-token-id))
)