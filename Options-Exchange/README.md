# Options Contract in Clarity

A smart contract built on Clarity that enables the creation, trading, and exercise of financial options on the Stacks blockchain.

## Overview

This contract provides a comprehensive implementation of options trading functionality, allowing users to:

- Create call and put options with customizable parameters
- Buy options directly from option writers
- Trade options on a secondary market
- Exercise options before expiration
- Manage option expiration

## Features

### Option Creation
- Create call or put options with customizable parameters:
  - Underlying asset identifier
  - Strike price
  - Premium
  - Expiration block height
  - Option type (call/put)
  - Amount/quantity

### Trading Capabilities
- Buy options directly from the option writer
- List options for sale at a specified price
- Cancel option listings
- Buy listed options from other users

### Exercise & Settlement
- Exercise call options by paying the strike price
- Exercise put options to receive the strike price
- Expire options after their expiration block height

### Data Organization
- Track options by ID, writer, and holder
- Query active options and filter by status

## Contract Structure

The contract is organized into several sections:

1. **Constants and Error Codes**: Defines error codes and option status values
2. **Data Structures**: Maps and variables that store option data
3. **Public Functions**: User-accessible functions for option operations
4. **Private Helper Functions**: Internal functions for managing option data
5. **Read-Only Functions**: Functions for querying contract state

## Constants

### Error Codes
- `ERR-NOT-AUTHORIZED (u1000)`: Operation not permitted
- `ERR-OPTION-NOT-FOUND (u1001)`: Option ID does not exist
- `ERR-OPTION-EXPIRED (u1002)`: Option has expired
- `ERR-ALREADY-EXERCISED (u1003)`: Option has already been exercised
- `ERR-INSUFFICIENT-BALANCE (u1004)`: Insufficient balance for operation
- `ERR-INVALID-EXPIRY (u1005)`: Invalid expiration block height
- `ERR-INVALID-STRIKE-PRICE (u1006)`: Invalid strike price
- `ERR-OPTION-NOT-OWNED (u1007)`: Option not owned by caller
- `ERR-OPTION-NOT-FOR-SALE (u1008)`: Option not listed for sale
- `ERR-INVALID-PRICE (u1009)`: Invalid price value
- `ERR-NOT-WRITER (u1010)`: Not the option writer
- `ERR-ALREADY-SETTLED (u1011)`: Option already settled

### Option Types
- `OPTION-TYPE-CALL (u1)`: Call option
- `OPTION-TYPE-PUT (u2)`: Put option

### Option Status
- `OPTION-STATUS-ACTIVE (u1)`: Option is active
- `OPTION-STATUS-EXERCISED (u2)`: Option has been exercised
- `OPTION-STATUS-EXPIRED (u3)`: Option has expired
- `OPTION-STATUS-FOR-SALE (u4)`: Option is listed for sale

## Data Structures

### Options Map
The primary data structure that stores option information:

```clarity
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
```

### Additional Maps
- `options-by-writer`: Maps writers to their option IDs
- `options-by-holder`: Maps holders to their option IDs

### Variables
- `option-count`: Tracks the total number of options created

## Public Functions

### `create-option`
Creates a new option with specified parameters.

```clarity
(define-public (create-option 
    (underlying-asset (string-ascii 32)) 
    (strike-price uint) 
    (premium uint) 
    (expiration uint) 
    (option-type uint)
    (amount uint))
```

### `buy-option`
Allows a user to buy an option directly from the writer.

```clarity
(define-public (buy-option (option-id uint))
```

### `list-option-for-sale`
Lists an option for sale at a specified price.

```clarity
(define-public (list-option-for-sale (option-id uint) (price uint))
```

### `cancel-option-listing`
Cancels a listing for an option.

```clarity
(define-public (cancel-option-listing (option-id uint))
```

### `buy-listed-option`
Buys an option listed for sale by another user.

```clarity
(define-public (buy-listed-option (option-id uint))
```

### `exercise-call-option`
Exercises a call option by paying the strike price.

```clarity
(define-public (exercise-call-option (option-id uint))
```

### `exercise-put-option`
Exercises a put option to receive the strike price.

```clarity
(define-public (exercise-put-option (option-id uint))
```

### `expire-option`
Marks an option as expired after its expiration block height.

```clarity
(define-public (expire-option (option-id uint))
```

## Read-Only Functions

### `get-option-count`
Returns the total number of options created.

### `get-option`
Retrieves details for a specific option ID.

### `get-options-by-writer`
Gets all option IDs created by a specific writer.

### `get-options-by-holder`
Gets all option IDs owned by a specific holder.

### `get-active-options`
Returns a list of all active options.

## Usage Examples

### Creating a Call Option

```clarity
;; Create a call option for STX with strike price of 2 USD
;; Premium of 0.1 STX, expiring in 1000 blocks from now
;; Type is CALL (1), for 10 units
(contract-call? .options-contract create-option 
  "STX" 
  u200000000 
  u10000000 
  (+ block-height u1000) 
  u1 
  u10)
```

### Listing an Option for Sale

```clarity
;; List option #5 for sale at a price of 0.15 STX
(contract-call? .options-contract list-option-for-sale u5 u15000000)
```

### Exercising a Call Option

```clarity
;; Exercise call option #8
(contract-call? .options-contract exercise-call-option u8)
```

## Security Considerations

1. **Block Height Validation**: The contract uses block height for expiration timing. Consider network conditions when setting expiration.

2. **Option Limits**: The contract limits users to 100 options per writer/holder. Consider your use case requirements.

3. **Asset Transfer**: This contract handles STX transfers but would need integration with SIP-010 compliant tokens for other assets.

4. **Oracle Integration**: For real-world assets, consider integrating price oracles.

5. **Collateralization**: The current contract doesn't enforce collateralization requirements for option writers.