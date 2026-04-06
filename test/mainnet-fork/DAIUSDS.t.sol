// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

}

abstract contract DaiUsds_TestBase is ForkTestBase {

    IERC20Like internal constant USDS = IERC20Like(Ethereum.USDS);

    function setUp() public override {
        super.setUp();

        // Configure DAIUSDS rate limit (required for swap operations)
        bytes32 key = mainnetController.LIMIT_DAIUSDS_SWAP();
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 10_000_000e18, 1_000_000e18);
    }

}

contract MainnetController_DAIUSDS_SwapUSDSToDAI_Tests is DaiUsds_TestBase {

    function test_swapUSDSToDAI_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapUSDSToDAI(1_000_000e18);
    }

    function test_swapUSDSToDAI_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.swapUSDSToDAI(1_000_000e18);
    }

    function test_swapUSDSToDAI_zeroMaxAmount() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(mainnetController.LIMIT_DAIUSDS_SWAP(), 0, 0);
        vm.stopPrank();

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.swapUSDSToDAI(1e18);
    }

    function test_swapUSDSToDAI_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(almProxy), 20_000_000e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        mainnetController.swapUSDSToDAI(10_000_000e18 + 1);

        vm.prank(relayer);
        mainnetController.swapUSDSToDAI(10_000_000e18);
    }

    function test_swapUSDSToDAI_rateLimited() external {
        deal(Ethereum.USDS, address(almProxy), 20_000_000e18);

        bytes32 key = mainnetController.LIMIT_DAIUSDS_SWAP();

        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e18);

        mainnetController.swapUSDSToDAI(5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);
        assertEq(USDS.balanceOf(address(almProxy)),   15_000_000e18);
        assertEq(dai.balanceOf(address(almProxy)),    5_000_000e18);

        mainnetController.swapUSDSToDAI(5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(USDS.balanceOf(address(almProxy)),   10_000_000e18);
        assertEq(dai.balanceOf(address(almProxy)),    10_000_000e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.swapUSDSToDAI(1);

        skip(5);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);

        mainnetController.swapUSDSToDAI(5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(dai.balanceOf(address(almProxy)),    15_000_000e18);

        vm.stopPrank();
    }

    function test_swapUSDSToDAI() external {
        bytes32 key = mainnetController.LIMIT_DAIUSDS_SWAP();

        vm.prank(relayer);
        mainnetController.mintUSDS(1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e18);

        assertEq(USDS.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(USDS.totalSupply(),                USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(USDS.allowance(address(almProxy), Ethereum.DAI_USDS), 0);

        vm.record();

        vm.prank(relayer);
        mainnetController.swapUSDSToDAI(1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(key), 9_000_000e18);

        assertEq(USDS.balanceOf(address(almProxy)), 0);
        assertEq(USDS.totalSupply(),                USDS_SUPPLY);

        assertEq(dai.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + 1_000_000e18);

        assertEq(USDS.allowance(address(almProxy), Ethereum.DAI_USDS), 0);
    }

}

contract MainnetController_DAIUSDS_SwapDAIToUSDS_Tests is DaiUsds_TestBase {

    function test_swapDAIToUSDS_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapDAIToUSDS(1_000_000e18);
    }

    function test_swapDAIToUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.swapDAIToUSDS(1_000_000e18);
    }

    function test_swapDAIToUSDS_zeroMaxAmount() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(mainnetController.LIMIT_DAIUSDS_SWAP(), 0, 0);
        vm.stopPrank();

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.swapDAIToUSDS(1e18);
    }

    function test_swapDAIToUSDS_rateLimitCancellation() external {
        deal(Ethereum.USDS, address(almProxy), 10_000_000e18);

        bytes32 key = mainnetController.LIMIT_DAIUSDS_SWAP();

        vm.startPrank(relayer);

        mainnetController.swapUSDSToDAI(10_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(dai.balanceOf(address(almProxy)),    10_000_000e18);
        assertEq(USDS.balanceOf(address(almProxy)),   0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.swapUSDSToDAI(1);

        mainnetController.swapDAIToUSDS(4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
        assertEq(dai.balanceOf(address(almProxy)),    6_000_000e18);
        assertEq(USDS.balanceOf(address(almProxy)),   4_000_000e18);

        mainnetController.swapUSDSToDAI(4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(dai.balanceOf(address(almProxy)),    10_000_000e18);
        assertEq(USDS.balanceOf(address(almProxy)),   0);

        // Increase beyond maxAmount caps at maxAmount
        mainnetController.swapDAIToUSDS(10_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e18);
        assertEq(dai.balanceOf(address(almProxy)),    0);
        assertEq(USDS.balanceOf(address(almProxy)),   10_000_000e18);

        vm.stopPrank();
    }

    function test_swapDAIToUSDS() external {
        bytes32 key = mainnetController.LIMIT_DAIUSDS_SWAP();

        deal(address(dai), address(almProxy), 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e18);

        assertEq(USDS.balanceOf(address(almProxy)), 0);
        assertEq(USDS.totalSupply(),                USDS_SUPPLY);

        assertEq(dai.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);  // Supply not updated on deal

        assertEq(dai.allowance(address(almProxy), Ethereum.DAI_USDS), 0);

        vm.record();

        vm.prank(relayer);
        mainnetController.swapDAIToUSDS(1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e18);

        assertEq(USDS.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(USDS.totalSupply(),                USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.totalSupply(),                DAI_SUPPLY - 1_000_000e18);

        assertEq(dai.allowance(address(almProxy), Ethereum.DAI_USDS), 0);
    }

}
