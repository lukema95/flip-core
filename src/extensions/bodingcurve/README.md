English | [中文](./README.zh.md)

# Bonding Curve Pricing Contracts

This directory contains alternative pricing implementations for the Flip protocol, extending the base `Price.sol` contract with different bonding curve formulas.

## Contracts

### 1. LinearPrice.sol
Implements a linear multiplier pricing model: `Price = min(initialPrice + a * lastPrice, maxPrice)`

**Formula**: Each new token's price is calculated as the initial price plus a multiplier of the previous price, capped at maxPrice.

**Parameters**:
- `priceMultiplier`: The multiplier coefficient (in basis points, default 1100 = 1.1x)
- `maxPrice`: The maximum price limit stored in Storage contract (0 = no limit)
- `initialPrice`: The starting price for the first token

**Example**:
- Initial price: 1 ETH
- Multiplier: 1.1x (1100 basis points)
- Max price: 3 ETH
- Token 1: 1 ETH + 1.1 × 1 ETH = 2.1 ETH
- Token 2: min(1 ETH + 1.1 × 2.1 ETH, 3 ETH) = min(3.31 ETH, 3 ETH) = 3 ETH
- Token 3: min(1 ETH + 1.1 × 3 ETH, 3 ETH) = 3 ETH

### 2. FixedIncrementPrice.sol
Implements a fixed increment pricing model: `Price = min(initialPrice + x * a, maxPrice)`

**Formula**: Each new token's price increases by a fixed amount from the initial price, capped at maxPrice.

**Parameters**:
- `priceIncrement`: The fixed amount to add per token (default 0.1 ETH)
- `maxPrice`: The maximum price limit stored in Storage contract (0 = no limit)
- `initialPrice`: The starting price for the first token

**Example**:
- Initial price: 1 ETH
- Increment: 0.1 ETH
- Max price: 1.5 ETH
- Token 1: 1 ETH + 1 × 0.1 ETH = 1.1 ETH
- Token 2: 1 ETH + 2 × 0.1 ETH = 1.2 ETH
- Token 5: 1 ETH + 5 × 0.1 ETH = 1.5 ETH
- Token 6: min(1 ETH + 6 × 0.1 ETH, 1.5 ETH) = min(1.6 ETH, 1.5 ETH) = 1.5 ETH

## Architecture

Each pricing contract manages its own immutable parameters:

- `LinearPrice`: Manages `priceMultiplier` parameter (immutable)
- `FixedIncrementPrice`: Manages `priceIncrement` parameter (immutable)
- `maxPrice` is stored in the Storage contract and can be updated by the creator
- Both contracts implement the `IPrice` interface and work with the base `Storage` contract
- Price multiplier/increment parameters are set at deployment and cannot be changed afterward
- `maxPrice` provides a safety cap to prevent excessive price growth (0 = no limit)

## Usage

### Deployment

Deploy the pricing contracts with parameters (immutable after deployment):

```solidity
// Deploy LinearPrice with 1.1x multiplier
LinearPrice linearPrice = new LinearPrice(1100); // 1100 = 1.1x

// Deploy FixedIncrementPrice with 0.1 ETH increment
FixedIncrementPrice fixedPrice = new FixedIncrementPrice(0.1 ether);

// Set maxPrice in Storage contract (can be updated later)
storageContract.setMaxPrice(10 ether); // Set max price to 10 ETH
```

**Note**: Price multiplier/increment parameters are immutable and cannot be changed after deployment. `maxPrice` can be updated in the Storage contract.

### Calculating Prices

```solidity
// Get current buy price
uint256 buyPrice = linearPrice.getBuyPrice(storageContract);

// Get current sell price
uint256 sellPrice = linearPrice.getSellPrice(storageContract);

// Get prices with fees
uint256 buyPriceWithFee = linearPrice.getBuyPriceAfterFee(storageContract);
uint256 sellPriceWithFee = linearPrice.getSellPriceAfterFee(storageContract);

// Calculate price for specific supply
uint256 price = linearPrice.calculatePrice(storageContract, 5);
```

### Custom Calculations

```solidity
// Linear price with custom multiplier
uint256 price = linearPrice.calculatePriceWithMultiplier(
    storageContract, 
    5, // supply
    1500 // 1.5x multiplier
);

// Fixed increment with custom amount
uint256 price = fixedIncrementPrice.calculatePriceWithIncrement(
    storageContract,
    10, // supply
    0.3 ether // increment
);

// Calculate total cost for multiple tokens
uint256 totalCost = fixedIncrementPrice.calculateTotalCost(
    storageContract,
    0, // current supply
    3  // tokens to mint
);
```

## Comparison

| Model | Formula | Price Growth | Use Case |
|-------|---------|--------------|----------|
| Linear Multiplier | `initialPrice + a * lastPrice` | Exponential | High-value collections |
| Fixed Increment | `initialPrice + x * a` | Linear | Predictable pricing |
| Original (Square Root) | Complex formula | Moderate | Balanced growth |

## Testing

Run the tests to verify the pricing calculations:

```bash
forge test --match-contract BondingCurveTest -vv
```

## Integration

To use these pricing contracts with your Flip collection:

1. Deploy the desired pricing contract (`LinearPrice` or `FixedIncrementPrice`) with initial parameters
2. Update your `Storage` contract's `priceContract` address to point to the new pricing contract
3. Set the `maxPrice` in the Storage contract if desired
4. The Flip protocol will automatically use the new pricing model

### Parameter Management

- Price multiplier/increment parameters are immutable and cannot be changed after deployment
- `maxPrice` can be updated by the creator in the Storage contract
- Parameters are validated to ensure reasonable values
- All parameter changes emit events for transparency
- The creator can transfer ownership to another address

## Security Considerations

- Price multiplier/increment parameters are immutable and cannot be changed after deployment
- `maxPrice` is stored in Storage contract and can be updated by the creator
- Parameters are validated to prevent invalid values
- `maxPrice` provides protection against excessive price growth
- All calculations use Math library for safety
- All calculations are view functions for gas efficiency
- Fee calculations are handled separately from price calculations
