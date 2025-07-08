// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "cowprotocol/contracts/interfaces/IERC20.sol";

// Safe contracts
import {Safe} from "safe/Safe.sol";
import {SafeLib} from "composable-cow/test/libraries/SafeLib.t.sol";
import {Enum} from "safe/common/Enum.sol";

// Composable CoW
import {IConditionalOrder, ComposableCoW} from "composable-cow/src/ComposableCoW.sol";

// Polyswap
import {PolyswapOrder} from "../src/PolyswapOrder.sol";
import {Polyswap} from "../src/Polyswap.sol";


contract SubmitSingleOrder is Script {
    using SafeLib for Safe;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        Safe safe = Safe(payable(vm.envAddress("SAFE")));
        Polyswap p = Polyswap(vm.envAddress("POLYSWAP_HANDLER"));
        ComposableCoW composableCow = ComposableCoW(vm.envAddress("COMPOSABLE_COW"));
        bytes32 polymarketOrderHash = vm.envBytes32("POLYMARKET_ORDER_HASH");

        IERC20 sellToken = IERC20(vm.envAddress("SELL_TOKEN"));
        IERC20 buyToken = IERC20(vm.envAddress("BUY_TOKEN"));

        PolyswapOrder.Data memory polyswapOrder = PolyswapOrder.Data({
            sellToken: sellToken,
            buyToken: buyToken,
            receiver: address(0),
            sellAmount: 1e17, // 0.1 sell token
            minBuyAmount: 90e16, // 0.09 buy token
            t0: block.timestamp,
            t: block.timestamp + 30 days,
            polymarketOrderHash: polymarketOrderHash
        });

        IConditionalOrder.ConditionalOrderParams memory params = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(p),
            salt: keccak256(abi.encodePacked("Polyswap", block.timestamp)),
            staticInput: abi.encode(polyswapOrder)
        });

        // bytes32 orderHash = composableCow.hash(params);
        // console.logBytes32(orderHash);

        vm.startBroadcast(deployerPrivateKey);

        // call to ComposableCoW to submit a single order
        safe.executeSingleOwner(
            address(composableCow),
            0,
            abi.encodeCall(
                composableCow.create,
                (
                    params,
                    true
                )
            ),
            Enum.Operation.Call,
            vm.addr(deployerPrivateKey)
        );

        vm.stopBroadcast();
    }
}
