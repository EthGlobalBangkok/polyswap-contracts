// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20, GPv2Order} from "cowprotocol/contracts/libraries/GPv2Order.sol";

import {IConditionalOrder} from "@composable-cow/interfaces/IConditionalOrder.sol";

import {Trading} from "exchange/mixins/Trading.sol";
import {OrderStatus} from "exchange/libraries/OrderStructs.sol";

// --- error strings

string constant INVALID_SAME_TOKEN = "same token";
string constant INVALID_TOKEN = "invalid token";
string constant INVALID_SELL_AMOUNT = "invalid sell amount";
string constant INVALID_MIN_BUY_AMOUNT = "invalid min buy amount";
string constant INVALID_POLYMARKET_ORDER_HASH = "invalid order hash";
string constant INVALID_START_DATE = "invalid start date";
string constant INVALID_END_DATE = "invalid end date";

/**
 * @title Polyswap Order Library
 * @dev Structs, errors, and functions for Polyswap orders.
 */
library PolyswapOrder {
    using SafeCast for uint256;

    // --- structs

    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 minBuyAmount; // minimum amount of buyToken to receive;
        uint256 t0; // start valide date of the order
        uint256 t; // maximum date for the order to be valid
        bytes32 polymarketOrderHash; // hash of the Polymarket order
    }

    // --- functions

    /**
     * @dev revert if the order is invalid
     * @param self The PolyswapOrder order to validate
     */
    function validate(Data memory self, Trading polymarket) internal view {
        if (!(self.sellToken != self.buyToken)) revert IConditionalOrder.OrderNotValid(INVALID_SAME_TOKEN);
        if (!(address(self.sellToken) != address(0) && address(self.buyToken) != address(0))) {
            revert IConditionalOrder.OrderNotValid(INVALID_TOKEN);
        }
        if (!(self.t0 > block.timestamp)) revert IConditionalOrder.OrderNotValid(INVALID_START_DATE);
        if (!(self.t > self.t0 && self.t < type(uint32).max)) revert IConditionalOrder.OrderNotValid(INVALID_END_DATE);
        if (!(self.sellAmount > 0)) revert IConditionalOrder.OrderNotValid(INVALID_SELL_AMOUNT);
        if (!(self.minBuyAmount > 0)) revert IConditionalOrder.OrderNotValid(INVALID_MIN_BUY_AMOUNT);

        // Check if the Polymarket order is valid and not filled or cancelled.
        if (!(self.polymarketOrderHash == 0)) revert IConditionalOrder.OrderNotValid(INVALID_POLYMARKET_ORDER_HASH);
        OrderStatus memory order = polymarket.getOrderStatus(self.polymarketOrderHash);
        if (order.remaining == 0 && order.isFilledOrCancelled == false) {
            revert IConditionalOrder.OrderNotValid(INVALID_POLYMARKET_ORDER_HASH);
        }
    }

    /**
     * @dev Generate the `GPv2Order` of the Polyswap order.
     * @param self The Polyswap order to generate the order for.
     * @return order The `GPv2Order` of the Polyswap order.
     */
    function orderFor(Data memory self, Trading polymarket) internal view returns (GPv2Order.Data memory order) {
        // First, validate and revert if the order is invalid.
        validate(self, polymarket);

        order = GPv2Order.Data({
            sellToken: self.sellToken,
            buyToken: self.buyToken,
            receiver: self.receiver,
            sellAmount: self.sellAmount,
            buyAmount: self.minBuyAmount,
            validTo: self.t.toUint32(),
            appData: self.polymarketOrderHash,
            feeAmount: 0,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: false,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });
    }
}
