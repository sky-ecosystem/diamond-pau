// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { StdCheats } from "../../lib/forge-std/src/StdCheats.sol";

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IAccessControls } from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../../src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";
import { ISwapAssetFacet } from "../../src/facets/swap-asset/ISwapAssetFacet.sol";

import { IMainnetControllerFull } from "../interfaces/IMainnetControllerFull.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function approve(address spender, uint256 amount) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

interface ISettleLike {

    function swapAsset_settleSwap(bytes32 paymentId) external;

}

interface IDealLike {

    function deal(address token, address account, uint256 newBalance) external;

}

function _callToken(address token, bytes memory data) {
    ( bool success, bytes memory returnData ) = token.call(data);

    require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "token-call-failed");
}

function _convertAmount(address assetFrom, address assetTo, uint256 amount) view returns (uint256) {
    uint256 decimalsFrom = IERC20Like(assetFrom).decimals();
    uint256 decimalsTo   = IERC20Like(assetTo).decimals();

    return decimalsFrom <= decimalsTo
        ? amount * (10 ** (decimalsTo - decimalsFrom))
        : amount / (10 ** (decimalsFrom - decimalsTo));
}

contract SettleRelay {

    function settle(address controller, bytes32 paymentId) external {
        ISettleLike(controller).swapAsset_settleSwap(paymentId);
    }

}

/// @dev A (potentially malicious) counterparty Controller that is also its own proxy.
contract MockCounterpartyController is StdCheats {

    enum Mode { Honest, SkipSettle, WrongPaymentId, WrongSettler, SettleTwice, FundFromElsewhere }

    Mode internal mode;

    int256 internal pullOffset;     // Adjusts how much of the initiator's `assetOut` is pulled.
    int256 internal approveOffset;  // Adjusts how much of the initiator's `assetIn` is approved.

    SettleRelay internal relay = new SettleRelay();

    function proxy() external view returns (address) {
        return address(this);
    }

    function CONTROLLER() external pure returns (bytes32) {
        return 0;
    }

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }

    function setMode(Mode mode_) external {
        mode = mode_;
    }

    function setPullOffset(int256 offset) external {
        pullOffset = offset;
    }

    function setApproveOffset(int256 offset) external {
        approveOffset = offset;
    }

    // NOTE: `msg.sender` is the initiating proxy. `assetIn` is what it sends, `assetOut` what it gets.
    function swapAsset_completeSwap(
        address assetOut,
        address assetIn,
        uint256 amountOut,
        address initiatorController,
        bytes32 paymentId
    )
        external
    {
        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        _callToken(
            assetIn,
            abi.encodeCall(IERC20Like.transferFrom, (msg.sender, address(this), uint256(int256(amountIn) + pullOffset)))
        );

        if (mode == Mode.FundFromElsewhere) {
            // Cantina sky-review-261102#3: rather than paying from this proxy, make the initiator's
            // `assetOut` balance increase from some other source (e.g. a reentrant
            // `sparkVault_take` / `otc_claim` through a sibling Controller of the initiating proxy).
            deal(assetOut, msg.sender, IERC20Like(assetOut).balanceOf(msg.sender) + amountOut);
            return;
        }

        if (mode == Mode.SkipSettle) return;

        _callToken(
            assetOut,
            abi.encodeCall(IERC20Like.approve, (msg.sender, uint256(int256(amountOut) + approveOffset)))
        );

        if (mode == Mode.WrongSettler) {
            relay.settle(initiatorController, paymentId);
            return;
        }

        ISettleLike(initiatorController).swapAsset_settleSwap(
            mode == Mode.WrongPaymentId ? bytes32(uint256(paymentId) + 1) : paymentId
        );

        if (mode == Mode.SettleTwice) ISettleLike(initiatorController).swapAsset_settleSwap(paymentId);
    }

}

/// @dev An initiating Controller (of `proxy`) that pulls whatever it was approved for on settlement.
contract MockInitiatorController {

    IALMProxy public proxy;

    address internal asset;
    int256  internal pullOffset;

    bytes32 public lastPaymentId;

    constructor(IALMProxy proxy_) {
        proxy = proxy_;
    }

    function setAsset(address asset_) external {
        asset = asset_;
    }

    function setPullOffset(int256 offset) external {
        pullOffset = offset;
    }

    function swapAsset_settleSwap(bytes32 paymentId) external {
        lastPaymentId = paymentId;

        uint256 amount = uint256(int256(IERC20Like(asset).allowance(msg.sender, address(proxy))) + pullOffset);

        proxy.doCall(asset, abi.encodeCall(IERC20Like.transferFrom, (msg.sender, address(proxy), amount)));
    }

}

abstract contract SwapAsset_TestBase is ForkTestBase {

    address internal counterpartyAdmin     = makeAddr("counterpartyAdmin");
    address internal counterpartyAllocator = makeAddr("counterpartyAllocator");
    address internal unauthorized          = makeAddr("unauthorized");

    IALMProxy              internal counterpartyProxy;
    IMainnetControllerFull internal counterpartyController;
    IRateLimits            internal counterpartyRateLimits;

    MockInitiatorController internal mockInitiator;

    bytes32 internal constant PAYMENT_ID = keccak256("PAYMENT_ID");

    bytes32 internal initiateUSDSToUSDTKey;
    bytes32 internal initiateUSDTToUSDSKey;
    bytes32 internal completeUSDSToUSDTKey;
    bytes32 internal completeUSDTToUSDSKey;

    bytes32 internal completeCounterpartyUSDSToUSDTKey;
    bytes32 internal completeCounterpartyUSDTToUSDSKey;

    function setUp() public override {
        super.setUp();

        // Deploy and Configure the Counterparty PAU

        IAccessControls counterpartyAccessControls = IAccessControls(factory.deployAccessControls(counterpartyAdmin));

        counterpartyRateLimits = IRateLimits(factory.deployRateLimits(counterpartyAdmin));

        counterpartyProxy = IALMProxy(factory.deployALMProxy(counterpartyAdmin));

        counterpartyController = IMainnetControllerFull(
            payable(factory.deployController(address(counterpartyAccessControls), address(counterpartyProxy), address(counterpartyRateLimits)))
        );

        vm.startPrank(counterpartyAdmin);

        vm.label(address(counterpartyProxy),      "CP Proxy");
        vm.label(address(counterpartyController), "CP Controller");

        counterpartyProxy.grantRole(counterpartyProxy.CONTROLLER(),           address(counterpartyController));
        counterpartyRateLimits.grantRole(counterpartyRateLimits.CONTROLLER(), address(counterpartyController));

        counterpartyAccessControls.grantRole(ALLOCATOR_ROLE, counterpartyAllocator);

        // Stands in for the initiating Controller when `completeSwap` is called directly on the
        // Mainnet PAU by `counterpartyProxy`.
        mockInitiator = new MockInitiatorController(counterpartyProxy);

        counterpartyProxy.grantRole(counterpartyProxy.CONTROLLER(), address(mockInitiator));

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_ASSET_FACET";

        counterpartyController.updateIntegrations(integrationIds);

        vm.stopPrank();

        // Set Rate Limits on Mainnet PAU to allow swaps with the Counterparty PAU (in assetOut decimals)

        initiateUSDSToUSDTKey = mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(counterpartyProxy), address(counterpartyController), Ethereum.USDT);
        initiateUSDTToUSDSKey = mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDT, address(counterpartyProxy), address(counterpartyController), Ethereum.USDS);
        completeUSDSToUSDTKey = mainnetController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDS, address(counterpartyProxy), Ethereum.USDT);
        completeUSDTToUSDSKey = mainnetController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDT, address(counterpartyProxy), Ethereum.USDS);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, type(uint256).max, 0);
        rateLimits.setRateLimitData(initiateUSDTToUSDSKey, type(uint256).max, 0);
        rateLimits.setRateLimitData(completeUSDSToUSDTKey, type(uint256).max, 0);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, type(uint256).max, 0);

        vm.stopPrank();

        // Set Rate Limits on Counterparty PAU to allow swaps with Mainnet PAU (in assetOut decimals)

        completeCounterpartyUSDSToUSDTKey = counterpartyController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDS, address(almProxy), Ethereum.USDT);
        completeCounterpartyUSDTToUSDSKey = counterpartyController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDT, address(almProxy), Ethereum.USDS);

        vm.startPrank(counterpartyAdmin);

        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDSToUSDTKey, type(uint256).max, 0);
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDTToUSDSKey, type(uint256).max, 0);

        vm.stopPrank();
    }

}

contract MainnetController_SwapAsset_Tests is SwapAsset_TestBase {

    /**********************************************************************************************/
    /*** initiateSwap Tests                                                                     ***/
    /**********************************************************************************************/

    function test_initiateSwap_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapAsset_initiateSwap(address(0), address(0), address(0), 0);
    }

    function test_initiateSwap_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.swapAsset_initiateSwap(address(0), address(0), address(0), 0);
    }

    function test_initiateSwap_invalidCounterpartyController() external {
        vm.startPrank(counterpartyAdmin);
        counterpartyProxy.revokeRole(counterpartyProxy.CONTROLLER(), address(counterpartyController));
        vm.stopPrank();

        vm.expectRevert("SwapAssetFacet/invalid-counterparty-controller");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, 1_000_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_precisionLossBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6 + 1);

        vm.expectRevert("SwapAssetFacet/precision-loss");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12 - 1);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12);
    }

    function test_initiateSwap_reentrancy_swapWithSelf() external {
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);
        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(
            mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(almProxy), address(mainnetController), Ethereum.USDT),
            type(uint256).max,
            0
        );

        rateLimits.setRateLimitData(
            mainnetController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDT, address(almProxy), Ethereum.USDS),
            type(uint256).max,
            0
        );

        vm.stopPrank();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mainnetController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_sameAsset() external {
        vm.expectRevert("SwapAssetFacet/same-asset");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDS, 1_000_000e18);
    }

    function test_initiateSwap_amountOutMismatchBoundary() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        // Counterparty pulls less than `amountOut`, leaving allowance behind.
        mock.setPullOffset(-1);

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        _initiateWithMock(mock);

        // Counterparty tries to pull more than `amountOut`, exceeding the allowance.
        mock.setPullOffset(1);

        vm.expectRevert();
        _initiateWithMock(mock);

        mock.setPullOffset(0);

        _initiateWithMock(mock);
    }

    function test_initiateSwap_amountInNotApprovedBoundary() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        // Counterparty approves less than `amountIn`, so the initiator's pull fails.
        mock.setApproveOffset(-1);

        vm.expectRevert();
        _initiateWithMock(mock);

        // Counterparty over-approves, but the initiator only ever pulls exactly `amountIn`.
        mock.setApproveOffset(1);

        _initiateWithMock(mock);

        assertEq(usdt.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdt.balanceOf(address(mock)),     1_000_000e6);
    }

    function test_initiateSwap_notSettled() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        mock.setMode(MockCounterpartyController.Mode.SkipSettle);

        vm.expectRevert("SwapAssetFacet/not-settled");
        _initiateWithMock(mock);
    }

    // Cantina sky-review-261102#3: the initiating proxy's `assetIn` balance increases by exactly
    // `amountIn` and its `assetOut` balance decreases by exactly `amountOut`, which would have
    // passed the previous balance-delta checks, but the counterparty proxy never paid.
    function test_initiateSwap_fundedFromElsewhere() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        mock.setMode(MockCounterpartyController.Mode.FundFromElsewhere);

        vm.expectRevert("SwapAssetFacet/not-settled");
        _initiateWithMock(mock);
    }

    function test_initiateSwap_invalidPaymentId() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        mock.setMode(MockCounterpartyController.Mode.WrongPaymentId);

        vm.expectRevert("SwapAssetFacet/invalid-payment-id");
        _initiateWithMock(mock);
    }

    function test_initiateSwap_invalidSettler() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        mock.setMode(MockCounterpartyController.Mode.WrongSettler);

        vm.expectRevert("SwapAssetFacet/invalid-settler");
        _initiateWithMock(mock);
    }

    function test_initiateSwap_alreadySettled() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        mock.setMode(MockCounterpartyController.Mode.SettleTwice);

        vm.expectRevert("SwapAssetFacet/already-settled");
        _initiateWithMock(mock);
    }

    function test_initiateSwap_mockCounterparty() external {
        MockCounterpartyController mock = _setUpMockCounterparty();

        _initiateWithMock(mock);

        assertEq(usds.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(usds.balanceOf(address(mock)),     1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdt.balanceOf(address(mock)),     1_000_000e6);

        assertEq(usds.allowance(address(almProxy), address(mock)), 0);
    }

    function test_initiateSwap_usdsToUSDT() external {
        deal(Ethereum.USDS, address(almProxy),          2_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 3_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);
        // `maxAmount = 10m`, `lastAmount = 5m` so we can see increases.
        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(initiateUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        vm.startPrank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          2_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usdt.balanceOf(address(almProxy)),          0);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 3_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 5_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 5_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 5_000_000e6);

        assertEq(usds.allowance(address(almProxy), address(counterpartyProxy)), 0);

        vm.record();

        vm.expectEmit(address(counterpartyController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(almProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            1_000_000e6,
            1_000_000e18
        );

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();
        _assertReentrancyGuardWrittenToTwice(address(counterpartyController));

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 2_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 6_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 6_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 4_000_000e6);

        assertEq(usds.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    function test_initiateSwap_usdtToUSDS() external {
        deal(Ethereum.USDT, address(almProxy),          2_000_000e6);
        deal(Ethereum.USDS, address(counterpartyProxy), 3_000_000e18);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(initiateUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        vm.startPrank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 3_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 5_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 5_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 5_000_000e6);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);

        vm.record();

        vm.expectEmit(address(counterpartyController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(almProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            1_000_000e6,
            1_000_000e18
        );

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();
        _assertReentrancyGuardWrittenToTwice(address(counterpartyController));

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 2_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 6_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 4_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 4_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 6_000_000e6);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    function test_initiateSwap_usdtToUSDS_skipIncreaseRateLimit() external {
        deal(Ethereum.USDT, address(almProxy),          2_000_000e6);
        deal(Ethereum.USDS, address(counterpartyProxy), 3_000_000e18);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(initiateUSDTToUSDSKey, 10_000_000e6, 0, 5_000_000e6, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(initiateUSDSToUSDTKey, 0, 0);
        vm.stopPrank();

        vm.startPrank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        counterpartyRateLimits.setRateLimitData(completeCounterpartyUSDTToUSDSKey, 0, 0);
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 3_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 5_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 5_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 0);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);

        vm.record();

        vm.expectEmit(address(counterpartyController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(almProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            1_000_000e6,
            1_000_000e18
        );

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();
        _assertReentrancyGuardWrittenToTwice(address(counterpartyController));

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 2_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(initiateUSDSToUSDTKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(initiateUSDTToUSDSKey), 4_000_000e6);

        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDSToUSDTKey), 4_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(completeCounterpartyUSDTToUSDSKey), 0);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    /**********************************************************************************************/
    /*** completeSwap Tests                                                                     ***/
    /**********************************************************************************************/

    function test_completeSwap_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapAsset_completeSwap(address(0), address(0), 0, address(0), bytes32(0));
    }

    function test_completeSwap_precisionLossBoundary() external {
        mockInitiator.setAsset(Ethereum.USDS);

        deal(Ethereum.USDS, address(almProxy),          1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        IERC20Like(Ethereum.USDT).approve(address(almProxy), 1_000_000e6 + 1);

        vm.expectRevert("SwapAssetFacet/precision-loss");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12 - 1, address(mockInitiator), PAYMENT_ID);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_zeroMaxAmount() external {
        mockInitiator.setAsset(Ethereum.USDT);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(unauthorized);
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_rateLimitBoundary() external {
        mockInitiator.setAsset(Ethereum.USDT);

        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18 + 1e12);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6 + 1, address(mockInitiator), PAYMENT_ID);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_transferFromFailedOnReturnFalse() external {
        mockInitiator.setAsset(Ethereum.USDT);

        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_transferFromFailedOnNonStandardReturnData() external {
        mockInitiator.setAsset(Ethereum.USDT);

        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_transferFromSuccessNoReturnData() external {
        mockInitiator.setAsset(Ethereum.USDT);

        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);
    }

    function test_completeSwap_invalidInitiatorController() external {
        vm.expectRevert("SwapAssetFacet/invalid-initiator-controller");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, makeAddr("notController"), PAYMENT_ID);
    }

    function test_completeSwap_notPulledBoundary() external {
        mockInitiator.setAsset(Ethereum.USDT);

        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        // Initiator pulls less than approved, leaving allowance behind.
        mockInitiator.setPullOffset(-1);

        vm.expectRevert("SwapAssetFacet/not-pulled");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        // Initiator tries to pull more than approved.
        mockInitiator.setPullOffset(1);

        vm.expectRevert();
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        mockInitiator.setPullOffset(0);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        assertEq(mockInitiator.lastPaymentId(), PAYMENT_ID);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    function test_completeSwap_usdsToUSDT() external {
        mockInitiator.setAsset(Ethereum.USDS);

        deal(Ethereum.USDS, address(almProxy),          2_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 3_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);
        // `maxAmount = 10m`, `lastAmount = 5m` so we can see increases.
        rateLimits.setRateLimitData(completeUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          2_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usdt.balanceOf(address(almProxy)),          0);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 3_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 5_000_000e6);

        vm.prank(address(counterpartyProxy));
        IERC20Like(Ethereum.USDT).approve(address(almProxy), 1_000_000e6);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18, address(mockInitiator), PAYMENT_ID);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 2_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 6_000_000e6);
    }

    function test_completeSwap_usdtToUSDS() external {
        mockInitiator.setAsset(Ethereum.USDT);

        deal(Ethereum.USDS, address(counterpartyProxy), 2_000_000e18);
        deal(Ethereum.USDT, address(almProxy),          3_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDSToUSDTKey, 10_000_000e18, 0, 5_000_000e18, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 10_000_000e6,  0, 5_000_000e6,  vm.getBlockTimestamp());
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 2_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          3_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 5_000_000e6);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            1_000_000e6,
            1_000_000e18
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 6_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 4_000_000e6);
    }

    function test_completeSwap_usdtToUSDS_skipIncreaseRateLimit() external {
        mockInitiator.setAsset(Ethereum.USDT);

        deal(Ethereum.USDS, address(counterpartyProxy), 2_000_000e18);
        deal(Ethereum.USDT, address(almProxy),          3_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 10_000_000e6, 0, 5_000_000e6, vm.getBlockTimestamp());
        rateLimits.setRateLimitData(completeUSDSToUSDTKey, 0, 0);
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 2_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          3_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 5_000_000e6);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwap(
            address(counterpartyProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            1_000_000e6,
            1_000_000e18
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6, address(mockInitiator), PAYMENT_ID);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 4_000_000e6);
    }

    /**********************************************************************************************/
    /*** settleSwap Tests                                                                       ***/
    /**********************************************************************************************/

    function test_settleSwap_noPendingSettlement() external {
        vm.expectRevert("SwapAssetFacet/invalid-payment-id");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_settleSwap(bytes32(0));

        vm.expectRevert("SwapAssetFacet/invalid-payment-id");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_settleSwap(PAYMENT_ID);
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _setUpMockCounterparty() internal returns (MockCounterpartyController mock) {
        mock = new MockCounterpartyController();

        vm.label(address(mock), "Mock CP Controller/Proxy");

        deal(Ethereum.USDS, address(almProxy), 2_000_000e18);
        deal(Ethereum.USDT, address(mock),     2_000_000e6);

        bytes32 key = mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(mock), address(mock), Ethereum.USDT);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, type(uint256).max, 0);
    }

    function _initiateWithMock(MockCounterpartyController mock) internal {
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mock), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

}
