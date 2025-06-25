// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {
    IConditionalOrder,
    IConditionalOrderGenerator,
    GPv2Order,
    BaseConditionalOrder
} from "@composable-cow/BaseConditionalOrder.sol";
import {ComposableCoW} from "@composable-cow/ComposableCoW.sol";

import {Trading} from "exchange/mixins/Trading.sol";
import {OrderStatus} from "exchange/libraries/OrderStructs.sol";

import {PolyswapOrder} from "./PolyswapOrder.sol";

// --- error strings
string constant INVALID_HASH = "invalid hash";
string constant CONDITION_NOT_MET = "condition not met";
string constant POLYMARKET_ORDER_CANCELLED = "polymarket order cancelled";

/**
 * @title Polyswap Conditional Order
 * @dev This contract implements the logic for generating a tradeable order based on a Polyswap order.
 *      It inherits from BaseConditionalOrder to work with the ComposableCoW framework.
 *
 */
contract Polyswap is BaseConditionalOrder {
    ComposableCoW public immutable composableCow;
    Trading public immutable polymarket;

    constructor(ComposableCoW _composableCow, Trading _polymarket) {
        composableCow = _composableCow;
        polymarket = _polymarket;
    }

    /**
     * @inheritdoc IConditionalOrderGenerator
     * @dev `owner`, `sender`, 'ctx' and `offchainInput` is not used.
     */
    function getTradeableOrder(address, address, bytes32, bytes calldata staticInput, bytes calldata)
        public
        view
        override
        returns (GPv2Order.Data memory order)
    {
        /**
         * @dev Decode the payload into a Polyswap bundle and get the order. `orderFor` will revert if it is not
         * currently a valid order.
         */
        PolyswapOrder.Data memory polyswapOrder = abi.decode(staticInput, (PolyswapOrder.Data));

        order = PolyswapOrder.orderFor(polyswapOrder, polymarket);

        // check if the polymarket order is fulfilled
        OrderStatus memory status = polymarket.getOrderStatus(polyswapOrder.polymarketOrderHash);
        if (status.isFilledOrCancelled && status.remaining != 0) {
            revert IConditionalOrder.PollNever(POLYMARKET_ORDER_CANCELLED);
        }
        if (!(status.isFilledOrCancelled && status.remaining == 0)) {
            revert IConditionalOrder.PollTryNextBlock(CONDITION_NOT_MET);
        }
    }
}
