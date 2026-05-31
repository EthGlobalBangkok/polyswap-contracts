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

/**
 * @title Polyswap Conditional Order
 * @dev This contract implements the logic for generating a tradeable order based on a Polyswap order.
 *      It inherits from BaseConditionalOrder to work with the ComposableCoW framework.
 *
 */
contract Polyswap is BaseConditionalOrder {
    // Min fraction (bps) of the Polymarket maker amount that must be consumed to arm
    uint256 internal constant MIN_FILL_BPS = 1000;

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

        order = PolyswapOrder.orderFor(polyswapOrder);

        uint256 makerAmount = polyswapOrder.polymarketMakerAmount;
        OrderStatus memory status = polymarket.getOrderStatus(polyswapOrder.polymarketOrderHash);

        uint256 consumed;
        if (status.remaining == 0) {
            consumed = status.isFilledOrCancelled ? makerAmount : 0;
        } else {
            consumed = makerAmount > status.remaining ? makerAmount - status.remaining : 0;
        }

        if (consumed * 10_000 < makerAmount * MIN_FILL_BPS) {
            revert IConditionalOrder.PollTryNextBlock(CONDITION_NOT_MET);
        }
    }

    /**
     * @dev Get the hash of the Polyswap order.
     * @param polyswapOrder The Polyswap order to get the hash of.
     * @return The hash of the Polyswap order.
     */
    function getOrderHash(PolyswapOrder.Data memory polyswapOrder) public view returns (bytes32) {
        return GPv2Order.hash(PolyswapOrder.orderFor(polyswapOrder), composableCow.domainSeparator());
    }
}
