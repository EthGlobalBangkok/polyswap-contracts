// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IERC20} from "cowprotocol/contracts/interfaces/IERC20.sol";
import {GPv2Order} from "cowprotocol/contracts/libraries/GPv2Order.sol";

// Safe contracts
import {SafeProxy} from "safe/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "safe/proxies/SafeProxyFactory.sol";
import {Safe} from "safe/Safe.sol";
import {SafeLib} from "composable-cow/test/libraries/SafeLib.t.sol";
import {Enum} from "safe/common/Enum.sol";

// Composable CoW
import {IConditionalOrder, ComposableCoW} from "composable-cow/src/ComposableCoW.sol";
import {IValueFactory} from "composable-cow/src/interfaces/IValueFactory.sol";
import {ExtensibleFallbackHandler, ERC1271} from "safe/handler/ExtensibleFallbackHandler.sol";
import {SignatureVerifierMuxer} from "safe/handler/extensible/SignatureVerifierMuxer.sol";
import {ISafeSignatureVerifier} from "safe/handler/extensible/SignatureVerifierMuxer.sol";

// Polyswap contracts
import {PolyswapOrder, INVALID_END_DATE, INVALID_POLYMARKET_ORDER_HASH} from "../src/PolyswapOrder.sol";
import {Polyswap} from "../src/Polyswap.sol";

// Mock contracts
import {MockPolymarket} from "./MockPolymarket.sol";

// CTF Exchange
import {Trading} from "exchange/mixins/Trading.sol";
import {OrderStatus} from "exchange/libraries/OrderStructs.sol";

/**
 * @title PolyswapTest - Comprehensive test suite for Polyswap conditional orders
 * @dev Tests both mocked and real contract integrations on Polygon fork
 */
contract PolyswapTest is Test {
    using SafeLib for Safe;

    // ===== STATE VARIABLES =====

    // Real contracts on Polygon mainnet
    // BLINDSPOT: Need to verify these addresses are current for Polygon mainnet
    address public constant POLYGON_SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a; // SafeSingleton on Polygon
    SafeProxyFactory public constant POLYGON_SAFE_PROXY_FACTORY =
        SafeProxyFactory(0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67); // SafeProxyFactory on Polygon
    address public constant POLYGON_COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41; // CoW Settlement on Polygon
    address public constant POLYGON_COMPOSABLE_COW = 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74; // ComposableCoW on Polygon
    address public constant POLYGON_EXTENSIBLE_FALLBACK_HANDLER = 0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5; // ExtensibleFallbackHandler on Polygon
    address public constant POLYGON_TIMESTAMP_VALUE_FACTORY = 0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc; // TimestampValueFactory on Polygon

    // BLINDSPOT: Need real Polymarket contract address on Polygon
    // Polymarket CTF Exchange contract address
    address public constant POLYGON_POLYMARKET_EXCHANGE = address(0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E);

    // Test tokens on Polygon
    address public constant USDC_POLYGON = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant USDT_POLYGON = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant WMATIC_POLYGON = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // Contract instances
    ComposableCoW public composableCow;
    ExtensibleFallbackHandler public extensibleFallbackHandler;
    IValueFactory public timestampValueFactory;
    Polyswap public polyswap;

    // Mock contracts
    MockPolymarket public mockPolymarket;

    // Test accounts
    address public owner;
    address public user1;
    address public user2;

    Safe public testSafe;

    // Test data
    uint256 public constant FORK_BLOCK = 75_882_806;
    bytes32 public constant TEST_ORDER_HASH = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    // ===== EVENTS =====

    event ConditionalOrderCreated(address indexed owner, IConditionalOrder.ConditionalOrderParams params);
    event OrderFulfilled(bytes32 indexed orderHash, address indexed owner);

    // ===== SETUP =====

    function setUp() public {
        // Create fork of Polygon mainnet
        uint256 forkId = vm.createFork(vm.rpcUrl("polygon"), FORK_BLOCK);
        vm.selectFork(forkId);

        // Setup test accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        console.log("Owner:", owner);
        console.log("User1:", user1);
        console.log("User2:", user2);

        // Fund test accounts
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        // Setup real contracts from Polygon
        composableCow = ComposableCoW(POLYGON_COMPOSABLE_COW);
        extensibleFallbackHandler = ExtensibleFallbackHandler(POLYGON_EXTENSIBLE_FALLBACK_HANDLER);
        timestampValueFactory = IValueFactory(POLYGON_TIMESTAMP_VALUE_FACTORY);

        // Deploy mock Polymarket for isolated testing
        mockPolymarket = new MockPolymarket();

        // Deploy Polyswap with mock Polymarket
        polyswap = new Polyswap(composableCow, Trading(address(mockPolymarket)));

        // Deploy a test Safe
        testSafe = _deploySafe(owner);

        // Setup Safe with ExtensibleFallbackHandler and domain verifier
        _setupSafeForComposableCoW(testSafe, owner);

        // Setup test tokens with some balances
        _setupTestTokens();

        console.log("=== Setup Complete ===");
        console.log("Fork Block:", FORK_BLOCK);
        console.log("ComposableCoW:", address(composableCow));
        console.log("Polyswap:", address(polyswap));
        console.log("MockPolymarket:", address(mockPolymarket));
        console.log("Test Safe:", address(testSafe));
    }

    // ===== MOCK TESTS =====

    /**
     * @dev Test basic Polyswap order creation and validation with mocks
     */
    function test_mocked_orderBasicCreation() public {
        // Setup mock Polymarket order as not filled
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();

        // Should not revert on validation
        PolyswapOrder.validate(order);

        // Should generate valid GPv2Order
        GPv2Order.Data memory gpv2Order = PolyswapOrder.orderFor(order);

        assertEq(address(gpv2Order.sellToken), address(order.sellToken));
        assertEq(address(gpv2Order.buyToken), address(order.buyToken));
        assertEq(gpv2Order.sellAmount, order.sellAmount);
        assertEq(gpv2Order.buyAmount, order.minBuyAmount);
    }

    /**
     * @dev Test Polyswap conditional order execution when Polymarket order is fulfilled
     */
    function test_mocked_orderConditionalExecution() public {
        // Setup: Polymarket order not yet filled
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();

        // Should revert with PollTryNextBlock when condition not met
        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.PollTryNextBlock.selector, "condition not met"));
        polyswap.getTradeableOrder(address(testSafe), address(this), bytes32(0), abi.encode(order), bytes(""));

        // Fulfill the Polymarket order
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, true, 0);

        // Now should return valid order
        GPv2Order.Data memory gpv2Order =
            polyswap.getTradeableOrder(address(testSafe), address(this), bytes32(0), abi.encode(order), bytes(""));

        assertEq(address(gpv2Order.sellToken), address(order.sellToken));
        assertEq(gpv2Order.sellAmount, order.sellAmount);
    }

    /**
     * @dev Test order cancellation handling
     */
    function test_mocked_orderCancellation() public {
        // Setup: Polymarket order cancelled with remaining amount
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, true, 50);

        PolyswapOrder.Data memory order = _createTestOrder();

        // Should revert with PollNever when order is cancelled
        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.PollNever.selector, "polymarket order cancelled"));
        polyswap.getTradeableOrder(address(testSafe), address(this), bytes32(0), abi.encode(order), bytes(""));
    }

    /**
     * @dev Test order validation edge cases
     */
    /// forge-config: default.allow_internal_expect_revert = true
    function test_mocked_orderValidationEdgeCases() public {
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        // Test same token error
        PolyswapOrder.Data memory invalidOrder = _createTestOrder();
        invalidOrder.buyToken = invalidOrder.sellToken;

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, "same token"));
        PolyswapOrder.validate(invalidOrder);

        // Test zero sell amount
        invalidOrder = _createTestOrder();
        invalidOrder.sellAmount = 0;

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, "invalid sell amount"));
        PolyswapOrder.validate(invalidOrder);

        // Test zero buy amount
        invalidOrder = _createTestOrder();
        invalidOrder.minBuyAmount = 0;

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, "invalid min buy amount"));
        PolyswapOrder.validate(invalidOrder);

        // Test invalid time range
        invalidOrder = _createTestOrder();
        invalidOrder.t = invalidOrder.t0 - 1;

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, "invalid end date"));
        PolyswapOrder.validate(invalidOrder);
    }

    // ===== INTEGRATION TESTS WITH REAL CONTRACTS =====

    /**
     * @dev Test integration with real ComposableCoW contract
     */
    function test_integration_composableCoWOrderCreation() public {
        // BLINDSPOT: This test assumes we have proper Safe setup and token approvals
        // May need additional setup for real token interactions

        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();

        IConditionalOrder.ConditionalOrderParams memory params = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(address(polyswap)),
            salt: keccak256(abi.encodePacked("test-salt", block.timestamp)),
            staticInput: abi.encode(order)
        });

        // Create conditional order through Safe
        vm.prank(owner);
        testSafe.executeSingleOwner(
            address(composableCow),
            0,
            abi.encodeCall(composableCow.createWithContext, (params, timestampValueFactory, bytes(""), true)),
            Enum.Operation.Call,
            owner
        );

        // Verify order was created
        bytes32 orderHash = composableCow.hash(params);
        assertTrue(composableCow.singleOrders(address(testSafe), orderHash));
    }

    /**
     * @dev Test full order lifecycle with real ComposableCoW
     */
    function test_integration_composableCoWFullLifecycle() public {
        // BLINDSPOT: This test requires proper token setup and may need real liquidity
        // Consider using smaller amounts or mock tokens for testing

        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();
        order.sellAmount = 1000; // Smaller amount for testing
        order.minBuyAmount = 800;

        IConditionalOrder.ConditionalOrderParams memory params = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(address(polyswap)),
            salt: keccak256(abi.encodePacked("lifecycle-test", block.timestamp)),
            staticInput: abi.encode(order)
        });

        // Create order
        vm.prank(owner);
        testSafe.executeSingleOwner(
            address(composableCow), 0, abi.encodeCall(composableCow.create, (params, true)), Enum.Operation.Call, owner
        );

        bytes32 orderHash = composableCow.hash(params);
        assertTrue(composableCow.singleOrders(address(testSafe), orderHash));

        // Fulfill Polymarket condition
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, true, 0);

        // Get tradeable order
        (GPv2Order.Data memory gpv2Order, bytes memory signature) =
            composableCow.getTradeableOrderWithSignature(address(testSafe), params, bytes(""), new bytes32[](0));

        assertEq(gpv2Order.sellAmount, order.sellAmount);
        assertEq(gpv2Order.buyAmount, order.minBuyAmount);
        assertTrue(signature.length > 0);

        // Remove order
        vm.prank(owner);
        testSafe.executeSingleOwner(
            address(composableCow), 0, abi.encodeCall(composableCow.remove, (orderHash)), Enum.Operation.Call, owner
        );

        assertFalse(composableCow.singleOrders(address(testSafe), orderHash));
    }

    // ===== EDGE CASES AND ERROR CONDITIONS =====

    /**
     * @dev Test behavior with expired orders
     */
    /// forge-config: default.allow_internal_expect_revert = true
    function test_edgeCase_expiredOrder() public {
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();
        order.t = uint256(block.timestamp - 1); // Expired

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, INVALID_END_DATE));
        PolyswapOrder.validate(order);
    }

    /**
     * @dev Test behavior with invalid Polymarket order hash
     */
    /// forge-config: default.allow_internal_expect_revert = true
    function test_edgeCase_invalidPolymarketOrderHash() public {
        PolyswapOrder.Data memory order = _createTestOrder();
        order.polymarketOrderHash = bytes32(0);

        vm.expectRevert(abi.encodeWithSelector(IConditionalOrder.OrderNotValid.selector, INVALID_POLYMARKET_ORDER_HASH));
        PolyswapOrder.validate(order);
    }

    // TODO more negative tests

    /**
     * @dev Test gas consumption for various operations
     */
    function test_gasConsumption_orderOperations() public {
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, 100);

        PolyswapOrder.Data memory order = _createTestOrder();

        // Measure validation gas
        uint256 gasStart = gasleft();
        PolyswapOrder.validate(order);
        uint256 validationGas = gasStart - gasleft();
        console.log("Validation gas:", validationGas);

        // Measure order generation gas
        gasStart = gasleft();
        PolyswapOrder.orderFor(order);
        uint256 orderGenGas = gasStart - gasleft();
        console.log("Order generation gas:", orderGenGas);

        // Set reasonable gas limits
        assertTrue(validationGas < 50000, "Validation gas too high");
        assertTrue(orderGenGas < 30000, "Order generation gas too high");
    }

    /**
     * @dev Test isValidSafeSignature function from ComposableCoW in real context
     */
    function test_integration_isValidSafeSignature() public {
        // Setup: Polymarket order fulfilled so condition is met
        mockPolymarket.setOrderStatus(TEST_ORDER_HASH, true, 0);

        PolyswapOrder.Data memory order = _createTestOrder();

        // Create conditional order params
        IConditionalOrder.ConditionalOrderParams memory params = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(address(polyswap)),
            salt: keccak256(abi.encodePacked("signature-test", block.timestamp)),
            staticInput: abi.encode(order)
        });

        // Create the conditional order first
        vm.prank(owner);
        testSafe.executeSingleOwner(
            address(composableCow), 0, abi.encodeCall(composableCow.create, (params, false)), Enum.Operation.Call, owner
        );

        // Get the tradeable order that would be generated
        GPv2Order.Data memory gpv2Order =
            polyswap.getTradeableOrder(address(testSafe), address(this), bytes32(0), abi.encode(order), bytes(""));

        // Create the payload for isValidSafeSignature
        ComposableCoW.PayloadStruct memory payload = ComposableCoW.PayloadStruct({
            proof: new bytes32[](0), // Empty proof for single order
            params: params,
            offchainInput: bytes("")
        });

        // Hash the order for signature validation
        bytes32 orderHash = GPv2Order.hash(gpv2Order, composableCow.domainSeparator());

        bytes32 domainSeparator = composableCow.domainSeparator();

        // Call isValidSafeSignature - this should succeed
        bytes4 result = composableCow.isValidSafeSignature(
            testSafe,
            address(this),
            orderHash,
            domainSeparator,
            GPv2Order.TYPE_HASH,
            abi.encode(gpv2Order),
            abi.encode(payload)
        );

        // Should return the ERC1271 magic value
        assertEq(result, ERC1271.isValidSignature.selector);
    }

    // /**
    //  * @dev Test with maximum uint256 values to check for overflows
    //  */
    // function test_EdgeCaseMaxValues() public {
    //     mockPolymarket.setOrderStatus(TEST_ORDER_HASH, false, type(uint256).max);

    //     PolyswapOrder.Data memory order = _createTestOrder();
    //     order.sellAmount = type(uint256).max;
    //     order.minBuyAmount = type(uint256).max;

    //     // Should handle large values gracefully
    //     // BLINDSPOT: May need to check for specific overflow behaviors
    //     // depending on the implementation details

    //     try PolyswapOrder.validate(order, Trading(address(mockPolymarket))) {
    //         // If validation passes, try order generation
    //         PolyswapOrder.orderFor(order, Trading(address(mockPolymarket)));
    //     } catch {
    //         // Expected to revert with large values
    //         assertTrue(true, "Expected revert with max values");
    //     }
    // }

    // ===== FUZZ TESTS =====

    /**
     * @dev Fuzz test order creation with random valid parameters
     */
    function test_fuzz_orderCreation(uint256 sellAmount, uint256 minBuyAmount, uint256 timeOffset, bytes32 orderHash)
        public
    {
        // Bound inputs to reasonable ranges
        sellAmount = bound(sellAmount, 1, 1e30);
        minBuyAmount = bound(minBuyAmount, 1, 1e30);
        timeOffset = bound(timeOffset, 1, 365 days);
        vm.assume(orderHash != bytes32(0));

        mockPolymarket.setOrderStatus(orderHash, false, 100);

        PolyswapOrder.Data memory order = PolyswapOrder.Data({
            sellToken: IERC20(USDC_POLYGON),
            buyToken: IERC20(USDT_POLYGON),
            receiver: address(1),
            sellAmount: sellAmount,
            minBuyAmount: minBuyAmount,
            t0: block.timestamp,
            t: block.timestamp + timeOffset,
            polymarketOrderHash: orderHash,
            appData: bytes32(0)
        });

        // Should not revert with valid parameters
        PolyswapOrder.validate(order);
        GPv2Order.Data memory gpv2Order = PolyswapOrder.orderFor(order);

        assertEq(gpv2Order.sellAmount, sellAmount);
        assertEq(gpv2Order.buyAmount, minBuyAmount);
    }

    // ===== HELPER FUNCTIONS =====

    /**
     * @dev Create a test Safe with single owner
     */
    function _deploySafe(address singleOwner) internal returns (Safe) {
        // BLINDSPOT: This is a simplified Safe deployment
        // Real deployment might require more complex setup
        address[] memory owners = new address[](1);
        owners[0] = singleOwner;

        // Deploy Safe with minimal setup
        // This is a simplified version - real deployment would use SafeProxyFactory
        SafeProxy safeProxy = SafeLib.createSafe(
            POLYGON_SAFE_PROXY_FACTORY,
            Safe(payable(POLYGON_SAFE_SINGLETON)),
            owners,
            1,
            address(extensibleFallbackHandler),
            0
        );
        Safe safe = Safe(payable(safeProxy));

        return safe;
    }

    /**
     * @dev Setup Safe for ComposableCoW integration
     */
    function _setupSafeForComposableCoW(Safe safe, address safeOwner) internal {
        vm.startPrank(safeOwner);

        console.log("safe", address(safe));

        // Set fallback handler
        safe.executeSingleOwner(
            address(safe),
            0,
            abi.encodeWithSelector(safe.setFallbackHandler.selector, address(extensibleFallbackHandler)),
            Enum.Operation.Call,
            safeOwner
        );

        // Set domain verifier for CoW Protocol through the fallback handler
        bytes32 domainSeparator = composableCow.domainSeparator();
        safe.executeSingleOwner(
            address(safe),
            0,
            abi.encodeWithSelector(
                SignatureVerifierMuxer.setDomainVerifier.selector,
                domainSeparator,
                ISafeSignatureVerifier(composableCow)
            ),
            Enum.Operation.Call,
            safeOwner
        );

        vm.stopPrank();
    }

    /**
     * @dev Setup test tokens with balances
     */
    function _setupTestTokens() internal {
        // Give test accounts some token balances
        deal(USDC_POLYGON, address(testSafe), 1000000 * 1e6); // 1M USDC
        deal(USDT_POLYGON, address(testSafe), 1000000 * 1e6); // 1M USDT
        deal(WETH_POLYGON, address(testSafe), 100 * 1e18); // 100 WETH

        // Approve tokens for CoW Protocol
        // BLINDSPOT: May need to approve for specific CoW Protocol contracts
        // The actual approval target might be different
    }

    /**
     * @dev Create a standard test order
     */
    function _createTestOrder() internal view returns (PolyswapOrder.Data memory) {
        return PolyswapOrder.Data({
            sellToken: IERC20(USDC_POLYGON),
            buyToken: IERC20(USDT_POLYGON),
            receiver: address(1),
            sellAmount: 100000, // 0.1 USDC (6 decimals)
            minBuyAmount: 80000, // 0.08 USDT (6 decimals)
            t0: block.timestamp,
            t: block.timestamp + 1 days,
            polymarketOrderHash: TEST_ORDER_HASH,
            appData: bytes32(0x053e648e24f8653eb9cffe71f170227d25f8fd69c135bcf2125ae24f4d210b9b)
        });
    }
}
