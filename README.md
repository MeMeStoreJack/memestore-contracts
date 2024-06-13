# MeMe Store contracts in Solidity

This repository contains the smart contracts for the MeMe Store platform, divided into two main functionalities outlined below.

- Issuing MEME ERC20s and adding liquidity, which can be done through the FairMint or BondingCurve methods
- Referrer Relationship Contract, setting up user on-chain referrer relationships

## MEME ERC20 Contract

### FairMint Method

The ERC20 issuer specifies the mint price, quantity, and target amount.
Once the specified quantity is reached, liquidity is added to a third-party swap platform. Currently, uniswap v2 and its forks are supported.

### BondingCurve Method

The ERC20 issuer specifies the Bonding Curve parameters, allowing users to buy and sell on the Bonding Curve.
When the conditions set by the ERC20 issuer for adding liquidity are met, liquidity is added to a third-party swap platform. Currently, uniswap v2 and its forks are supported.

## Referrer Relationship Contract
Users set their referrer, which is used in contract to distribute referrer fees when users buy or sell ERC20s on BondingCurve.

## Usage

```bash
npm install
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
```
