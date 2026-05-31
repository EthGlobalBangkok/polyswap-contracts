// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ComposableCoW} from "@composable-cow/ComposableCoW.sol";
import {Trading} from "exchange/mixins/Trading.sol";

import {Polyswap} from "../src/Polyswap.sol";

/**
 * @title Deploy
 * @dev Deploys both Polyswap handlers — one bound to the standard CTF Exchange and one to the
 *      Neg Risk CTF Exchange. Reads addresses from the environment so it is reusable across networks.
 *
 *      Required env: PRIVATE_KEY, COMPOSABLE_COW, CTF_EXCHANGE_V2_ADDRESS, NEG_RISK_CTF_EXCHANGE_V2_ADDRESS
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ComposableCoW composableCow = ComposableCoW(vm.envAddress("COMPOSABLE_COW"));
        Trading ctfExchange = Trading(vm.envAddress("CTF_EXCHANGE_V2_ADDRESS"));
        Trading negRiskExchange = Trading(vm.envAddress("NEG_RISK_CTF_EXCHANGE_V2_ADDRESS"));

        vm.startBroadcast(deployerPrivateKey);

        Polyswap standardHandler = new Polyswap(composableCow, ctfExchange);
        Polyswap negRiskHandler = new Polyswap(composableCow, negRiskExchange);

        vm.stopBroadcast();

        console.log("Polyswap (standard CTF Exchange):", address(standardHandler));
        console.log("Polyswap (Neg Risk CTF Exchange):", address(negRiskHandler));
        console.log("-> NEXT_PUBLIC_POLYSWAP_HANDLER         =", address(standardHandler));
        console.log("-> NEXT_PUBLIC_POLYSWAP_HANDLER_NEGRISK =", address(negRiskHandler));
    }
}
