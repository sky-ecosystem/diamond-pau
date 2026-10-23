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

    bytes32 internal usdcToUSDTKey;
    bytes32 internal usdtToUSDCKey;

    function setUp() public override {
        super.setUp();

        // Deploy and Configure the Counterparty PAU

        IAccessControls counterpartyAccessControls = IAccessControls(factory.deployAccessControls(counterpartyAdmin));

        IRateLimits counterpartyRateLimits = IRateLimits(factory.deployRateLimits(counterpartyAdmin));

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

        // Set Rate Limits on Mainnet PAU to allow swaps with the Counterparty PAU

        usdcToUSDTKey = mainnetController.swapAsset_getSwapRateLimitKey(Ethereum.USDC, address(counterpartyProxy), Ethereum.USDT);
        usdtToUSDCKey = mainnetController.swapAsset_getSwapRateLimitKey(Ethereum.USDT, address(counterpartyProxy), Ethereum.USDC);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(usdcToUSDTKey, type(uint256).max, 0);
        rateLimits.setRateLimitData(usdtToUSDCKey, type(uint256).max, 0);

        vm.stopPrank();

        // Set Rate Limits on Counterparty PAU to allow swaps with Mainnet PAU

        vm.startPrank(counterpartyAdmin);

        counterpartyRateLimits.setRateLimitData(
            counterpartyController.swapAsset_getSwapRateLimitKey(Ethereum.USDC, address(almProxy), Ethereum.USDT),
            type(uint256).max,
            0
        );

        counterpartyRateLimits.setRateLimitData(
            counterpartyController.swapAsset_getSwapRateLimitKey(Ethereum.USDT, address(almProxy), Ethereum.USDC),
            type(uint256).max,
            0
        );

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
        rateLimits.setRateLimitData(usdcToUSDTKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 0);
    }

    function test_initiateSwap_rateLimitedBoundary() external {
        deal(Ethereum.USDC, address(almProxy),          1_000_000e6 + 1);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6 + 1);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdcToUSDTKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6 + 1);

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);
    }

    function test_initiateSwap_amountOutMismatchBoundary() external {
        deal(Ethereum.USDC, address(almProxy),          1_000_000e6);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.mockCall(Ethereum.USDC, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 - 1));

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);

        vm.mockCall(Ethereum.USDC, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 + 1));

        vm.expectRevert("SwapAssetFacet/amountOut-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);

        vm.clearMockedCalls();

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);
    }

    function test_initiateSwap_amountInMismatchBoundary() external {
        deal(Ethereum.USDC, address(almProxy),          1_000_000e6);
        deal(Ethereum.USDT, address(counterpartyProxy), 1_000_000e6);

        vm.mockCall(Ethereum.USDT, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 - 1));

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);

        vm.mockCall(Ethereum.USDT, abi.encodeCall(IERC20Like.balanceOf, (address(almProxy))), abi.encode(1_000_000e6 + 1));

        vm.expectRevert("SwapAssetFacet/amountIn-mismatch");
        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);

        vm.clearMockedCalls();

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);
    }

    function test_initiateSwap() external {
        deal(Ethereum.USDC, address(almProxy),          2_000_000e6);
        deal(Ethereum.USDT, address(counterpartyProxy), 3_000_000e6);

        assertEq(usdc.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdc.balanceOf(address(counterpartyProxy)), 0);

        assertEq(usdt.balanceOf(address(almProxy)),          0);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 3_000_000e6);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwapInitiated(
            address(counterpartyProxy),
            Ethereum.USDC,
            Ethereum.USDT,
            1_000_000e6
        );

        vm.prank(allocator);
        mainnetController.swapAsset_initiateSwap(address(counterpartyController), Ethereum.USDC, Ethereum.USDT, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usdc.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdc.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(usdt.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 2_000_000e6);
    }

    /**********************************************************************************************/
    /*** completeSwap Tests                                                                     ***/
    /**********************************************************************************************/

    function test_completeSwap_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapAsset_completeSwap(address(0), address(0), 0);
    }

    function test_completeSwap_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUSDCKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 0);
    }

    function test_completeSwap_rateLimitedBoundary() external {
        deal(Ethereum.USDC, address(counterpartyProxy), 1_000_000e6 + 1);
        deal(Ethereum.USDT, address(almProxy),          1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        usdc.approve(address(almProxy), 1_000_000e6 + 1);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUSDCKey, 1_000_000e6, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6 + 1);

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferFromFailedOnReturnFalse() external {
        vm.mockCall(
            Ethereum.USDC,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e6)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferFromFailedOnNonStandardReturnData() external {
        vm.mockCall(
            Ethereum.USDC,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e6)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-from-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferFromSuccessNoReturnData() external {
        deal(Ethereum.USDT, address(almProxy), 1_000_000e6 + 1);

        vm.mockCall(
            Ethereum.USDC,
            abi.encodeCall(IERC20Like.transferFrom, (address(counterpartyProxy), address(almProxy), 1_000_000e6)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferFailedOnReturnFalse() external {
        deal(Ethereum.USDC, address(counterpartyProxy), 1_000_000e6);

        vm.prank(address(counterpartyProxy));
        usdc.approve(address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            abi.encode(false)
        );

        vm.expectRevert("SwapAssetFacet/transfer-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferFailedOnNonStandardReturnData() external {
        deal(Ethereum.USDC, address(counterpartyProxy), 1_000_000e6);

        vm.prank(address(counterpartyProxy));
        usdc.approve(address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            abi.encode(bytes32(0), bytes32(0))
        );

        vm.expectRevert("SwapAssetFacet/transfer-failed");
        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap_transferSuccessNoReturnData() external {
        deal(Ethereum.USDC, address(counterpartyProxy), 1_000_000e6);

        vm.prank(address(counterpartyProxy));
        usdc.approve(address(almProxy), 1_000_000e6);

        vm.mockCall(
            Ethereum.USDT,
            abi.encodeCall(IERC20Like.transfer, (address(counterpartyProxy), 1_000_000e6)),
            ""
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);
    }

    function test_completeSwap() external {
        deal(Ethereum.USDC, address(counterpartyProxy), 2_000_000e6);
        deal(Ethereum.USDT, address(almProxy),          3_000_000e6);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(counterpartyProxy)), 2_000_000e6);

        assertEq(usdt.balanceOf(address(almProxy)),          3_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 0);

        vm.prank(address(counterpartyProxy));
        usdc.approve(address(almProxy), 1_000_000e6);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapAssetFacet.SwapAssetSwapCompleted(
            address(counterpartyProxy),
            Ethereum.USDT,
            Ethereum.USDC,
            1_000_000e6
        );

        vm.prank(address(counterpartyProxy));
        mainnetController.swapAsset_completeSwap(Ethereum.USDT, Ethereum.USDC, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usdc.balanceOf(address(almProxy)),          1_000_000e6);
        assertEq(usdc.balanceOf(address(counterpartyProxy)), 1_000_000e6);

        assertEq(usdt.balanceOf(address(almProxy)),          2_000_000e6);
        assertEq(usdt.balanceOf(address(counterpartyProxy)), 1_000_000e6);
    }

}
