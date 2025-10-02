# PixelVault NFT Marketplace

A decentralized NFT marketplace smart contract built on Stacks blockchain using Clarity language. PixelVault enables users to mint, list, buy, and sell NFTs with built-in royalty support for creators.

## Features

- **NFT Minting**: Create unique NFTs with custom metadata and royalty settings
- **Marketplace Listing**: List NFTs for sale at custom prices
- **Secure Trading**: Buy and sell NFTs with automatic royalty distribution
- **Creator Royalties**: Support for creator royalties up to 10% on secondary sales
- **Ownership Management**: Transfer contract ownership with validation
- **Safety Checks**: Comprehensive validation and error handling

## Contract Overview

### NFT Asset
- **Asset Name**: `pixelvault`
- **Token Standard**: Non-fungible token with unique uint identifiers

### Key Components

#### Data Storage
- **Tokens Map**: Stores token metadata (owner, creator, URI, royalty percentage)
- **Listings Map**: Tracks active marketplace listings with price and seller information
- **Next Token ID**: Auto-incrementing counter for minting new tokens

#### Constants (Error Codes)
- `err-owner-only (u100)`: Only contract owner can perform this action
- `err-not-token-owner (u101)`: Caller is not the token owner
- `err-listing-not-found (u102)`: No listing exists for this token
- `err-invalid-price (u103)`: Price must be greater than zero
- `err-invalid-token-id (u104)`: Token ID does not exist
- `err-invalid-uri (u105)`: URI cannot be empty
- `err-invalid-royalty (u106)`: Royalty exceeds maximum allowed
- `err-invalid-principal (u107)`: Invalid principal address
- `err-self-transfer (u108)`: Cannot transfer to self

## Public Functions

### Minting

#### `mint`
```clarity
(define-public (mint (uri (string-ascii 256)) (royalty uint))
```
Mints a new NFT with specified metadata.

**Parameters:**
- `uri`: Token metadata URI (max 256 ASCII characters, must not be empty)
- `royalty`: Royalty percentage in basis points (0-1000, representing 0-10%)

**Returns:** Token ID of the newly minted NFT

**Example:**
```clarity
(contract-call? .pixelvault mint "ipfs://QmX..." u500) ;; 5% royalty
```

### Marketplace Operations

#### `list-nft`
```clarity
(define-public (list-nft (token-id uint) (price uint))
```
Lists an NFT for sale on the marketplace.

**Parameters:**
- `token-id`: ID of the token to list
- `price`: Sale price in microSTX (must be greater than 0)

**Requirements:**
- Caller must own the token
- Token must exist

#### `cancel-listing`
```clarity
(define-public (cancel-listing (token-id uint))
```
Removes an NFT listing from the marketplace.

**Parameters:**
- `token-id`: ID of the token to delist

**Requirements:**
- Caller must be the seller who created the listing

#### `buy-nft`
```clarity
(define-public (buy-nft (token-id uint))
```
Purchases a listed NFT from the marketplace.

**Parameters:**
- `token-id`: ID of the token to purchase

**Process:**
1. Validates listing exists and seller still owns the NFT
2. Calculates and transfers royalty to original creator
3. Transfers remaining payment to seller
4. Transfers NFT ownership to buyer
5. Updates token ownership record
6. Removes listing from marketplace

**Requirements:**
- Buyer must have sufficient STX balance
- Listing must be active
- Seller must still own the token

### Administrative

#### `transfer-contract-ownership`
```clarity
(define-public (transfer-contract-ownership (new-owner principal))
```
Transfers contract ownership to a new principal.

**Parameters:**
- `new-owner`: Principal address of the new owner

**Requirements:**
- Caller must be current contract owner
- New owner must be a valid principal
- Cannot transfer to self

## Read-Only Functions

#### `get-contract-owner`
Returns the current contract owner principal.

#### `get-token-details`
```clarity
(define-read-only (get-token-details (token-id uint))
```
Returns complete token information including owner, creator, URI, and royalty.

#### `get-listing`
```clarity
(define-read-only (get-listing (token-id uint))
```
Returns listing details including price and seller for a listed token.

#### `get-token-uri`
```clarity
(define-read-only (get-token-uri (token-id uint))
```
Returns the metadata URI for a specific token.

#### `get-next-token-id`
Returns the next token ID that will be minted.

## Royalty System

The contract implements a royalty system where creators earn a percentage on all secondary sales:

- Royalties are specified in basis points (1 basis point = 0.01%)
- Maximum royalty: 1000 basis points (10%)
- Royalties are automatically calculated and transferred during purchases
- Formula: `royalty-amount = (price × royalty) / 10000`

**Example:**
- Token price: 1,000,000 microSTX (1 STX)
- Royalty: 500 basis points (5%)
- Royalty amount: 50,000 microSTX (0.05 STX)
- Seller receives: 950,000 microSTX (0.95 STX)

## Events

The contract emits events for key actions:

- `contract-ownership-transferred`: When contract ownership changes
- `nft-minted`: When a new NFT is created
- `nft-listed`: When an NFT is listed for sale
- `listing-cancelled`: When a listing is removed
- `nft-sold`: When an NFT is purchased

## Security Features

- **Ownership Verification**: All operations verify token ownership before execution
- **Race Condition Prevention**: Validates seller still owns NFT before purchase
- **Principal Validation**: Ensures valid addresses for ownership transfers
- **Input Validation**: Comprehensive checks on all parameters
- **Self-Transfer Prevention**: Blocks meaningless self-transfers

## Deployment

1. Deploy the contract to Stacks blockchain
2. The deploying address becomes the initial contract owner
3. Token IDs begin at 1 and auto-increment with each mint

## Usage Examples

### Mint an NFT
```clarity
(contract-call? .pixelvault mint "ipfs://Qm..." u250)
;; Mints NFT with 2.5% royalty, returns token ID
```

### List for Sale
```clarity
(contract-call? .pixelvault list-nft u1 u1000000)
;; Lists token #1 for 1 STX
```

### Purchase NFT
```clarity
(contract-call? .pixelvault buy-nft u1)
;; Buys token #1, pays seller and creator royalty
```

### Cancel Listing
```clarity
(contract-call? .pixelvault cancel-listing u1)
;; Removes token #1 from marketplace
```
