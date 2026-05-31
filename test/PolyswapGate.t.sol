// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "cowprotocol/contracts/interfaces/IERC20.sol";
import {GPv2Order} from "cowprotocol/contracts/libraries/GPv2Order.sol";

import {IConditionalOrder} from "@composable-cow/interfaces/IConditionalOrder.sol";
import {ComposableCoW} from "@composable-cow/ComposableCoW.sol";
import {Trading} from "exchange/mixins/Trading.sol";

import {PolyswapOrder, INVALID_MAKER_AMOUNT} from "../src/PolyswapOrder.sol";
import {Polyswap} from "../src/Polyswap.sol";
import {MockPolymarket} from "./MockPolymarket.sol";

/**
 * @title PolyswapGateTest — fill-fraction gate unit tests (no fork required).
 * @dev Exercises Polyswap.getTradeableOrder against MockPolymarket order statuses. The handler's gate
 *      depends only on the Polymarket exchange, so ComposableCoW is left unset.
 */
contract PolyswapGateTest is Test {
    Polyswap internal polyswap;
    MockPolymarket internal mockPolymarket;

    address internal constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address internal constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    bytes32 internal constant ORDER_HASH = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    uint256 internal constant MAKER_AMOUNT = 1_000_000; // gate arms at 10% = 100_000 consumed

    function setUp() public {
        mockPolymarket = new MockPolymarket();
        polyswap = new Polyswap(ComposableCoW(address(0)), Trading(address(mockPolymarket)));
    }

    function _order() internal view returns (PolyswapOrder.Data memory) {
        return PolyswapOrder.Data({
            sellToken: IERC20(USDC),
            buyToken: IERC20(USDT),
            receiver: address(1),
            sellAmount: 100000,
            minBuyAmount: 80000,
            t0: block.timestamp,
            t: block.timestamp + 1 days,
            polymarketOrderHash: ORDER_HASH,
            appData: bytes32(0),
            polymarketMakerAmount: MAKER_AMOUNT
        });
    }

    function _expectNotMet(PolyswapOrder.Data memory order) internal {
        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.PollTryNextBlock.selector, "condition not met"));
        polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
    }

    function _expectArms(PolyswapOrder.Data memory order) internal view {
        GPv2Order.Data memory o =
            polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
        assertEq(o.sellAmount, order.sellAmount);
    }

    function test_untouched_notMet() public {
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 0);
        _expectNotMet(_order());
    }

    function test_remainingEqualsMaker_notMet() public {
        mockPolymarket.setOrderStatus(ORDER_HASH, false, MAKER_AMOUNT);
        _expectNotMet(_order());
    }

    function test_partialBelowThreshold_notMet() public {
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 950_000); // 5% consumed
        _expectNotMet(_order());
    }

    function test_partialJustBelowThreshold_notMet() public {
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 900_001); // 9.9999% consumed
        _expectNotMet(_order());
    }

    function test_thresholdAndAbove_arm() public {
        // exactly 10% consumed (remaining 900_000) → arms
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 900_000);
        _expectArms(_order());

        // price-improvement dust (order-19 case): 98.75% consumed → arms
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 12_500);
        _expectArms(_order());

        // full fill → arms
        mockPolymarket.setOrderStatus(ORDER_HASH, true, 0);
        _expectArms(_order());
    }

    function test_zeroMakerAmount_invalid() public {
        mockPolymarket.setOrderStatus(ORDER_HASH, true, 0);
        PolyswapOrder.Data memory order = _order();
        order.polymarketMakerAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, INVALID_MAKER_AMOUNT));
        polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
    }

    function testFuzz_armsIffConsumedAtLeastTenPercent(uint256 remaining, bool filled) public {
        remaining = bound(remaining, 0, MAKER_AMOUNT);
        mockPolymarket.setOrderStatus(ORDER_HASH, filled, remaining);

        uint256 consumed = remaining == 0 ? (filled ? MAKER_AMOUNT : 0) : MAKER_AMOUNT - remaining;
        bool shouldArm = consumed * 10_000 >= MAKER_AMOUNT * 1000;

        PolyswapOrder.Data memory order = _order();
        if (shouldArm) {
            GPv2Order.Data memory o =
                polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
            assertEq(o.sellAmount, order.sellAmount);
        } else {
            vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.PollTryNextBlock.selector, "condition not met"));
            polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
        }
    }

    /**
     * @dev No overflow/underflow across the full realistic input space. makerAmount up to 1e30 raw
     *      (~1e24 pUSD, far beyond any real order); `makerAmount * 10_000` stays well under uint256
     *      max (overflow threshold ~1.15e73). `remaining` is left unbounded to exercise the
     *      `remaining > makerAmount` defensive branch (consumed = 0). The call must never panic and
     *      must arm exactly when consumed >= 10% of makerAmount.
     */
    function testFuzz_noOverflowUnderflow(uint256 makerAmount, uint256 remaining, bool filled) public {
        makerAmount = bound(makerAmount, 1, 1e30);
        mockPolymarket.setOrderStatus(ORDER_HASH, filled, remaining);

        PolyswapOrder.Data memory order = _order();
        order.polymarketMakerAmount = makerAmount;

        uint256 consumed;
        if (remaining == 0) {
            consumed = filled ? makerAmount : 0;
        } else {
            consumed = makerAmount > remaining ? makerAmount - remaining : 0;
        }
        bool shouldArm = consumed * 10_000 >= makerAmount * 1000;

        if (shouldArm) {
            GPv2Order.Data memory o =
                polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
            assertEq(o.sellAmount, order.sellAmount);
        } else {
            vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.PollTryNextBlock.selector, "condition not met"));
            polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
        }
    }

    /**
     * @dev A makerAmount above the multiplication-overflow threshold can only revert (0.8.x checked
     *      arithmetic), never mis-arm. Unreachable with real 6-decimal collateral; asserted for safety.
     */
    function test_absurdMakerAmount_safeFails() public {
        PolyswapOrder.Data memory order = _order();
        order.polymarketMakerAmount = type(uint256).max;
        mockPolymarket.setOrderStatus(ORDER_HASH, false, 1); // consumed = max - 1; *10_000 overflows
        vm.expectRevert(); // arithmetic panic — a safe fail, not an arm
        polyswap.getTradeableOrder(address(this), address(this), bytes32(0), abi.encode(order), bytes(""));
    }
}
