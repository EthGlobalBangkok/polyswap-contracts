// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {GPv2Order} from "cowprotocol/contracts/libraries/GPv2Order.sol";
import {IERC20} from "cowprotocol/contracts/interfaces/IERC20.sol";

// Safe contracts
import {Safe} from "safe/Safe.sol";
import {SafeLib} from "composable-cow/test/libraries/SafeLib.t.sol";
import {Enum} from "safe/common/Enum.sol";

// Composable CoW
import {IConditionalOrder, ComposableCoW} from "composable-cow/src/ComposableCoW.sol";
import {IValueFactory} from "composable-cow/src/interfaces/IValueFactory.sol";

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
            sellAmount: 100000, // 0.1 sell token
            minBuyAmount: 80000, // 0.08 buy token
            t0: block.timestamp,
            t: block.timestamp + 1 days,
            polymarketOrderHash: polymarketOrderHash,
            appData: bytes32(0x053e648e24f8653eb9cffe71f170227d25f8fd69c135bcf2125ae24f4d210b9b) // twap app data for the test
        });

        IConditionalOrder.ConditionalOrderParams memory params = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(p),
            salt: keccak256(abi.encodePacked("Polyswap", block.timestamp)),
            staticInput: abi.encode(polyswapOrder)
        });

        console.logBytes32(GPv2Order.hash(PolyswapOrder.orderFor(polyswapOrder), composableCow.domainSeparator()));

        vm.startBroadcast(deployerPrivateKey);

        // call to ComposableCoW to submit a single order
        safe.executeSingleOwner(
            address(composableCow),
            0,
            abi.encodeCall(
                composableCow.createWithContext,
                (
                    params,
                    IValueFactory(0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc), // TimestampValueFactory
                    bytes(""),
                    true
                )
            ),
            Enum.Operation.Call,
            vm.addr(deployerPrivateKey)
        );

        vm.stopBroadcast();
    }
}

contract ApproveSellTokenOnSafe is Script {
    using SafeLib for Safe;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        Safe safe = Safe(payable(vm.envAddress("SAFE")));
        IERC20 sellToken = IERC20(vm.envAddress("SELL_TOKEN"));
        address spender = vm.envAddress("SPENDER");

        safe.executeSingleOwner(
            address(sellToken),
            0,
            abi.encodeCall(sellToken.approve, (spender, type(uint256).max)),
            Enum.Operation.Call,
            vm.addr(deployerPrivateKey)
        );
    }
}
