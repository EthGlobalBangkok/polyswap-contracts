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

import {PolyswapOrder} from "./PolyswapOrder.sol";

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
    }
}
