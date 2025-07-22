# PegGuard - Stablecoin Depeg Protection Insurance

A parametric insurance protocol for DeFi risks built on the Stacks blockchain using Clarity smart contracts. PegGuard provides automated insurance coverage against stablecoin depegging events.

## Overview

PegGuard is a decentralized insurance protocol that protects users against stablecoin depeg risks. When a stablecoin loses its $1.00 peg beyond a specified threshold, the protocol automatically pays out insurance claims without requiring manual verification or lengthy claim processes.

## Key Features

- **Parametric Insurance**: Automatic payouts based on price data
- **Customizable Thresholds**: Set your own depeg trigger levels
- **Liquidity Pool**: Decentralized pool funded by liquidity providers
- **Multi-Stablecoin Support**: Support for various stablecoins
- **Transparent Pricing**: Clear premium calculation based on coverage and duration
- **No Claim Disputes**: Automated payouts eliminate subjective claim assessments

## How It Works

### For Insurance Buyers

1. **Purchase Policy**: Choose coverage amount, duration, and depeg threshold
2. **Pay Premium**: One-time premium payment based on risk parameters
3. **Monitor**: Track your policy and stablecoin prices
4. **Claim**: Automatic eligibility when depeg threshold is breached
5. **Receive Payout**: Instant payout proportional to depeg severity

### For Liquidity Providers

1. **Deposit STX**: Provide liquidity to the insurance pool
2. **Receive Shares**: Get share tokens representing your pool ownership
3. **Earn Premiums**: Collect fees from insurance buyers
4. **Manage Risk**: Share in both profits and potential payouts
5. **Withdraw**: Remove liquidity anytime (subject to pool capacity)

## Contract Functions

### Public Functions

#### Insurance Functions

```clarity
(purchase-policy stablecoin coverage-amount duration-blocks depeg-threshold)
```
Purchase an insurance policy with specified parameters.

- `stablecoin`: Name of the stablecoin to insure (e.g., "USDC", "USDT")
- `coverage-amount`: Maximum payout amount in microSTX
- `duration-blocks`: Policy duration in Stacks blocks
- `depeg-threshold`: Depeg trigger in basis points (e.g., 500 = 5%)

```clarity
(claim-payout policy-id)
```
Claim insurance payout when depeg conditions are met.

#### Liquidity Provider Functions

```clarity
(provide-liquidity amount)
```
Deposit STX to the insurance pool and receive share tokens.

```clarity
(withdraw-liquidity share-amount)
```
Withdraw STX from the pool by burning share tokens.

#### Oracle Functions

```clarity
(update-price stablecoin new-price)
```
Update stablecoin price data (contract owner only).

### Read-Only Functions

```clarity
(get-policy policy-id)
(get-user-policies user)
(get-stablecoin-price stablecoin)
(get-pool-info)
(get-provider-info provider)
```

## Usage Examples

### Purchasing Insurance

```clarity
;; Insure 10,000 STX worth of USDC for 1000 blocks with 5% depeg threshold
(contract-call? .peg-guard purchase-policy "USDC" u10000000000 u1000 u500)
```

### Providing Liquidity

```clarity
;; Deposit 50,000 STX to earn from insurance premiums
(contract-call? .peg-guard provide-liquidity u50000000000)
```

### Claiming Payout

```clarity
;; Claim payout for policy #1 when depeg occurs
(contract-call? .peg-guard claim-payout u1)
```

## Parameters

### Premium Calculation

- **Base Rate**: 0.5% (50 basis points) of coverage amount
- **Duration Multiplier**: Based on policy duration (minimum 1 week)
- **Formula**: `Premium = (Coverage × 0.5%) × (Duration / 1 week)`

### Depeg Thresholds

- **Minimum**: 1% (100 basis points)
- **Maximum**: 20% (2000 basis points)
- **Common Values**: 3% (300 bp), 5% (500 bp), 10% (1000 bp)

### Payout Calculation

- **Full Payout**: When price ≤ (100% - threshold)
- **Proportional**: Linear scaling between threshold and no payout
- **Maximum**: Cannot exceed policy coverage amount

## Risk Considerations

### For Insurance Buyers

- **Oracle Risk**: Price feeds depend on contract owner updates
- **Pool Risk**: Payouts require sufficient pool liquidity
- **Timing Risk**: Policies expire after specified duration
- **Threshold Risk**: Small depegs may not trigger payouts

### For Liquidity Providers

- **Payout Risk**: Large depeg events can drain pool funds
- **Duration Risk**: Funds may be locked during high-risk periods
- **Premium Risk**: Low insurance demand reduces earnings
- **Concentration Risk**: Multiple correlated depeg events

## Technical Specifications

### Blockchain
- **Network**: Stacks blockchain
- **Language**: Clarity smart contracts
- **Token**: STX for all transactions

### Data Structures
- **Policies**: Comprehensive policy storage with all parameters
- **Price Feeds**: Stablecoin price data with timestamps
- **Liquidity Pool**: Share-based pool management system

### Security Features
- **Access Control**: Owner-only functions for critical operations
- **Input Validation**: Comprehensive parameter checking
- **Balance Verification**: Ensures sufficient funds before operations
- **Overflow Protection**: Safe arithmetic operations

## Deployment

1. **Deploy Contract**: Deploy `peg-guard.clar` to Stacks mainnet
2. **Initialize Prices**: Set initial stablecoin prices
3. **Bootstrap Pool**: Initial liquidity provider deposits
4. **Market Launch**: Open for insurance purchases

## Governance

Currently, the protocol uses a simple owner-based governance model:

- **Price Oracle**: Contract owner updates stablecoin prices
- **Parameter Updates**: Contract owner can modify premium rates
- **Emergency Functions**: Contract owner emergency controls

Future versions may implement decentralized governance through token voting.
