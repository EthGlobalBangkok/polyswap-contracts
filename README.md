# 📈 PolySwap Smart Contracts

**Automated DeFi swaps triggered by on-chain prediction market outcomes.**

This repository contains the core smart contracts of **PolySwap**, a protocol that allows users to create conditional swap intents based on prediction markets like [Polymarket](https://polymarket.com/).

## 🛠️ What It Does

PolySwap lets users define CoW Swap orders that become valid only when a specific prediction market condition is met.
The contract checks the status of a Polymarket order and activates the swap only if that order has been fully filled (indicating the prediction condition was reached).

## 🧱 Contract Overview

* `BaseConditionalOrder`: Abstract contract to inherit for compatibility with ComposableCoW.
* `Polyswap`: Main contract that inherits from `BaseConditionalOrder` and verifies if the Polymarket order is filled.
* `PolySwapOrder`: Verifies if the Polyswap order parameters are correct and defines the order struct.

The `Polyswap` contract uses the Polymarket `CTFExchange` contract to check, via the `getOrderStatus()` function, whether:

* the order is filled or cancelled, and
* the remaining amount is `0`.

If both conditions are met, the swap is executed using the Composable CoW Swap protocol.

## 🧪 Stack

* [Solidity](https://soliditylang.org)
* [Foundry](https://book.getfoundry.sh/) for development and testing
* [Polygon PoS](https://polygon.technology) as the initial deployment network

## 🚀 Deployment

All contracts are deployed on **Polygon** for compatibility with Polymarket's on-chain infrastructure.

Contract Address: `0xC75f4070B794cE1EC7273767a7d67354F845c7ce`
View on [Sourcify](https://repo.sourcify.dev/137/0xC75f4070B794cE1EC7273767a7d67354F845c7ce)

## 🧑‍💻 Authors

 | [<img src="https://github.com/Intermarch3.png?size=85" width=85><br><sub>Lucas Leclerc</sub>](https://github.com/Intermarch3) | [<img src="https://github.com/Pybast.png?size=85" width=85><br><sub>Baptiste Florentin</sub>](https://github.com/Pybast)
 | :---: | :---: |