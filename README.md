# 📈 PolySwap Smart Contracts

**Automated DeFi swaps triggered by on-chain prediction market outcomes.**

This repository contains the core smart contracts of **PolySwap**, a protocol that allows users to create conditional swap intents based on prediction markets like [Polymarket](https://polymarket.com/).

## 🛠️ What It Does

PolySwap lets users define CoW Swap orders that become valid only when a specific prediction market condition is met.
The contract checks the status of a Polymarket order and activates the swap only if that order has been fully filled (indicating the prediction condition was reached).

## 🧱 Contract Overview (not finished yet)

* `IConditionalOrderGenerator`: Interface for condition-based CoW Swap orders.
* `PolySwapOrderVerifier`: Verifies whether the Polymarket condition (order filled) is satisfied.

The core logic uses the Polymarket `CTFExchange` contract to check if:

* the order is filled or cancelled, and
* the remaining amount is `0`.

## 🧪 Stack

* [Solidity](https://soliditylang.org)
* [Foundry](https://book.getfoundry.sh/) for development and testing
* [Polygon PoS](https://polygon.technology) as the initial deployment network

## 🚀 Deployment

All contracts are deployed on **Polygon** for compatibility with Polymarket's on-chain infrastructure.

Contract Address: `0xdeadbeef`

## 🧑‍💻 Authors

 | [<img src="https://github.com/Intermarch3.png?size=85" width=85><br><sub>Lucas Leclerc</sub>](https://github.com/Intermarch3) | [<img src="https://github.com/Pybast.png?size=85" width=85><br><sub>Baptiste Florentin</sub>](https://github.com/Pybast)
 | :---: | :---: |