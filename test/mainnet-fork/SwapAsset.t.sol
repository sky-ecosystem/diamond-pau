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

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

interface IDealLike {

    function deal(address token, address account, uint256 newBalance) external;

}

contract MockProxy {

    function CONTROLLER() external pure returns (bytes32) {
        return 0;
    }

    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }

}

contract MockCounterpartyController is StdCheats {

    address public proxy;

    int256 internal transferFromOffset;
    int256 internal transferOffset;

    constructor(address proxy_) {
        proxy = proxy_;
    }

    function setTransferFromOffset(int256 offset) external {
        transferFromOffset = offset;
    }

    function setTransferOffset(int256 offset) external {
        transferOffset = offset;
    }

    function swapAsset_completeSwap(address assetOut, address assetIn, uint256 amountOut) external {
        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        uint256 startingCallerAssetInBalance  = IERC20Like(assetIn).balanceOf(msg.sender);
        uint256 startingCallerAssetOutBalance = IERC20Like(assetOut).balanceOf(msg.sender);

        deal(assetIn,  msg.sender, uint256(int256(startingCallerAssetInBalance) - (int256(amountIn) + transferFromOffset)));
        deal(assetOut, msg.sender, uint256(int256(startingCallerAssetOutBalance) + (int256(amountOut) + transferOffset)));
    }

    function _convertAmount(address assetFrom, address assetTo, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 decimalsFrom = IERC20Like(assetFrom).decimals();
        uint256 decimalsTo   = IERC20Like(assetTo).decimals();

        return decimalsFrom <= decimalsTo
            ? amount * (10 ** (decimalsTo - decimalsFrom))
            : amount / (10 ** (decimalsFrom - decimalsTo));
    }

}

abstract contract SwapAsset_TestBase is ForkTestBase {

    address internal counterpartyAdmin     = makeAddr("counterpartyAdmin");
    address internal counterpartyAllocator = makeAddr("counterpartyAllocator");
    address internal unauthorized          = makeAddr("unauthorized");

    IALMProxy              internal counterpartyProxy;
    IMainnetControllerFull internal counterpartyController;
    IRateLimits            internal counterpartyRateLimits;

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

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_ASSET_FACET";

        counterpartyController.updateIntegrations(integrationIds);

        vm.stopPrank();

        // Set Rate Limits on Mainnet PAU to allow swaps with the Counterparty PAU (in assetOut decimals)

        initiateUSDSToUSDTKey = mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(counterpartyProxy), Ethereum.USDT);
        initiateUSDTToUSDSKey = mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDT, address(counterpartyProxy), Ethereum.USDS);
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
            mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(almProxy), Ethereum.USDT),
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

    function test_initiateSwap_amountOutMismatchBoundary() external {
        address mockCounterpartyProxy = address(new MockProxy());

        MockCounterpartyController mockCounterpartyController = new MockCounterpartyController(mockCounterpartyProxy);

        deal(Ethereum.USDS, address(almProxy), 2_000_000e18);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(mockCounterpartyProxy), Ethereum.USDT),
            type(uint256).max,
            0
        );
        vm.stopPrank();

        mockCounterpartyController.setTransferFromOffset(-1);

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        mockCounterpartyController.setTransferFromOffset(1);

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        mockCounterpartyController.setTransferFromOffset(0);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_amountOutMismatch_sameAsset() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18);
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(counterpartyProxy), Ethereum.USDS),
            1_000_000e18,
            0
        );
        vm.stopPrank();

        vm.startPrank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(
            counterpartyController.swapAsset_getCompleteSwapRateLimitKey(Ethereum.USDS, address(almProxy), Ethereum.USDS),
            1_000_000e18,
            0
        );
        vm.stopPrank();

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDS, 1_000_000e18);
    }

    function test_initiateSwap_amountInMismatchBoundary() external {
        address mockCounterpartyProxy = address(new MockProxy());

        MockCounterpartyController mockCounterpartyController = new MockCounterpartyController(mockCounterpartyProxy);

        deal(Ethereum.USDS, address(almProxy), 2_000_000e18);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.swapAsset_getInitiateSwapRateLimitKey(Ethereum.USDS, address(mockCounterpartyProxy), Ethereum.USDT),
            type(uint256).max,
            0
        );
        vm.stopPrank();

        mockCounterpartyController.setTransferOffset(-1);

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        mockCounterpartyController.setTransferOffset(1);

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        mockCounterpartyController.setTransferOffset(0);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(mockCounterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
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
        mainnetController.swapAsset_completeSwap(address(0), address(0), 0);
    }

    function test_completeSwap_precisionLossBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        IERC20Like(Ethereum.USDT).approve(address(almProxy), 1_000_000e6 + 1);

        vm.expectRevert("SwapAssetFacet/precision-loss");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12 - 1);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12);
    }

    function test_completeSwap_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(unauthorized);
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18 + 1e12);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(completeUSDTToUSDSKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferFromFailedOnReturnFalse() external {
        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferFromFailedOnNonStandardReturnData() external {
        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferFromSuccessNoReturnData() external {
        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferFailedOnReturnFalse() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferFailedOnNonStandardReturnData() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_transferSuccessNoReturnData() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);
    }

    function test_completeSwap_usdsToUSDT() external {
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 2_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 6_000_000e6);
    }

    function test_completeSwap_usdtToUSDS() external {
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 6_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 4_000_000e6);
    }

    function test_completeSwap_usdtToUSDS_skipIncreaseRateLimit() external {
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(completeUSDSToUSDTKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(completeUSDTToUSDSKey), 4_000_000e6);
    }

}
