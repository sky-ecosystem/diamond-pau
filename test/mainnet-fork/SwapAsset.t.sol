// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IAccessControls } from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../../src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";
import { ISwapAssetFacet } from "../../src/facets/swap-asset/ISwapAssetFacet.sol";

import { IMainnetControllerFull } from "../interfaces/IMainnetControllerFull.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

abstract contract SwapAsset_TestBase is ForkTestBase {

    address internal counterpartyAdmin     = makeAddr("counterpartyAdmin");
    address internal counterpartyAllocator = makeAddr("counterpartyAllocator");

    IALMProxy              internal counterpartyProxy;
    IMainnetControllerFull internal counterpartyController;
    IRateLimits            internal counterpartyRateLimits;

    bytes32 internal usdsToUSDTKey;
    bytes32 internal usdtToUSDSKey;
    bytes32 internal counterpartyUSDSToUSDTKey;
    bytes32 internal counterpartyUSDTToUSDSKey;

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

        counterpartyProxy.grantRole(counterpartyProxy.CONTROLLER(),           address(counterpartyController));
        counterpartyRateLimits.grantRole(counterpartyRateLimits.CONTROLLER(), address(counterpartyController));

        counterpartyAccessControls.grantRole(ALLOCATOR_ROLE, counterpartyAllocator);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_ASSET_FACET";

        counterpartyController.updateIntegrations(integrationIds);

        vm.stopPrank();

        // Set Rate Limits on Mainnet PAU to allow swaps with the Counterparty PAU (in assetOut decimals)

        usdsToUSDTKey = mainnetController.swapAsset_getSwapRateLimitKey(Ethereum.USDS, address(counterpartyProxy), Ethereum.USDT);
        usdtToUSDSKey = mainnetController.swapAsset_getSwapRateLimitKey(Ethereum.USDT, address(counterpartyProxy), Ethereum.USDS);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(usdsToUSDTKey, 5_000_000e18, 0);
        rateLimits.setRateLimitData(usdtToUSDSKey, 5_000_000e6,  0);

        vm.stopPrank();

        // Set Rate Limits on Counterparty PAU to allow swaps with Mainnet PAU (in assetOut decimals)

        counterpartyUSDSToUSDTKey = counterpartyController.swapAsset_getSwapRateLimitKey(Ethereum.USDS, address(almProxy), Ethereum.USDT);
        counterpartyUSDTToUSDSKey = counterpartyController.swapAsset_getSwapRateLimitKey(Ethereum.USDT, address(almProxy), Ethereum.USDS);

        vm.startPrank(counterpartyAdmin);

        counterpartyRateLimits.setRateLimitData(counterpartyUSDSToUSDTKey, 5_000_000e18, 0);
        counterpartyRateLimits.setRateLimitData(counterpartyUSDTToUSDSKey, 5_000_000e6,  0);

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

    function test_initiateSwap_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdsToUSDTKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_rateLimitedBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdsToUSDTKey, 1_000_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_invalidCounterpartyController() external {
        vm.startPrank(counterpartyAdmin);
        counterpartyProxy.revokeRole(counterpartyProxy.CONTROLLER(), address(counterpartyController));
        vm.stopPrank();

        vm.expectRevert("SwapAssetFacet/invalid-counterparty-controller");
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

    function test_initiateSwap_counterpartyZeroMaxAmount() external {
        vm.prank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(counterpartyUSDTToUSDSKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_counterpartyRateLimitedBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6 + 1);

        vm.prank(counterpartyAdmin);
        counterpartyRateLimits.setRateLimitData(counterpartyUSDTToUSDSKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18 + 1e12);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_amountOutMismatchBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.mockCall(Ethereum.USDS, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e18 - 1));

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        vm.mockCall(Ethereum.USDS, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e18 + 1));

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        vm.clearMockedCalls();

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_amountInMismatchBoundary() external {
        deal(Ethereum.USDS, address(almProxy),          1_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.mockCall(Ethereum.USDT, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 - 1));

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        vm.mockCall(Ethereum.USDT, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 + 1));

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);

        vm.clearMockedCalls();

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDS, Ethereum.USDT, 1_000_000e18);
    }

    function test_initiateSwap_usdsToUSDT() external {
        deal(Ethereum.USDS, address(almProxy),          2_000_000e18);
        deal(Ethereum.USDT, address(counterpartyProxy), 3_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          2_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usdt.balanceOf(address(almProxy)),          0);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 3_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUSDTKey),                         5_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(counterpartyUSDTToUSDSKey), 5_000_000e6);

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

        assertEq(rateLimits.getCurrentRateLimit(usdsToUSDTKey),                         4_000_000e18);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(counterpartyUSDTToUSDSKey), 4_000_000e6);

        assertEq(usds.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    function test_initiateSwap_usdtToUSDS() external {
        deal(Ethereum.USDT, address(almProxy),          2_000_000e6);
        deal(Ethereum.USDS, address(counterpartyProxy), 3_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 3_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey),                         5_000_000e6);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(counterpartyUSDSToUSDTKey), 5_000_000e18);

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

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey),                         4_000_000e6);
        assertEq(counterpartyRateLimits.getCurrentRateLimit(counterpartyUSDSToUSDTKey), 4_000_000e18);

        assertEq(usdt.allowance(address(almProxy), address(counterpartyProxy)), 0);
    }

    function test_initiateSwap_rateLimited() external {
        deal(Ethereum.USDT, address(almProxy),          9_000_000e6);
        deal(Ethereum.USDS, address(counterpartyProxy), 9_000_000e18);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUSDSKey, 5_000_000e6, uint256(1_000_000e6) / 1 days);

        vm.prank(counterpartyAdmin);
        counterpartyRateLimits.setUnlimitedRateLimitData(counterpartyUSDSToUSDTKey);

        vm.startPrank(allocator);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 5_000_000e6);
        assertEq(usdt.balanceOf(address(almProxy)),             9_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),             0);

        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDT, Ethereum.USDS, 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 4_000_000e6);
        assertEq(usdt.balanceOf(address(almProxy)),             8_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),             1_000_000e18);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 4_041_666.6664e6);
        assertEq(usdt.balanceOf(address(almProxy)),             8_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),             1_000_000e18);

        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDT, Ethereum.USDS, 4_041_666.6664e6);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 0);
        assertEq(usdt.balanceOf(address(almProxy)),             3_958_333.3336e6);
        assertEq(usds.balanceOf(address(almProxy)),             5_041_666.6664e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDT, Ethereum.USDS, 1);

        vm.stopPrank();
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
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18 + 1e12);

        vm.expectRevert("SwapAssetFacet/precision-loss");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18 + 1e12 - 1);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18 + 1e12);
    }

    function test_completeSwap_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUSDSKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
    }

    function test_completeSwap_rateLimitedBoundary() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 1_000_000e18 + 1e12);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usds.approve(address(almProxy), 1_000_000e18 + 1e12);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUSDSKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18 + 1e12);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
    }

    function test_completeSwap_transferFromFailedOnReturnFalse() external {
        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
    }

    function test_completeSwap_transferFromFailedOnNonStandardReturnData() external {
        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
    }

    function test_completeSwap_transferFromSuccessNoReturnData() external {
        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDS,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e18)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);
    }

    function test_completeSwap() external {
        deal(Ethereum.USDS, address(counterpartyProxy), 2_000_000e18);
        deal(Ethereum.USDT, address(almProxy),          3_000_000e6);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 2_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          3_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 5_000_000e6);

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
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDS, 1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),          1_000_000e18);
        assertEq(usds.balanceOf(address(counterpartyProxy)), 1_000_000e18);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdtToUSDSKey), 4_000_000e6);
    }

}
