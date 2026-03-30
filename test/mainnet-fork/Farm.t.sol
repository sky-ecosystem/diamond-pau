// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

abstract contract Farm_TestBase is ForkTestBase {

    address internal constant FARM = 0x173e314C7635B45322cd8Cb14f44b312e079F3af;  // USDS SPK farm

    IERC20Like internal constant USDS = IERC20Like(Ethereum.USDS);

    address internal unauthorized = makeAddr("unauthorized");

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(
            makeAddressKey(mainnetController.LIMIT_FARM_DEPOSIT(), FARM),
            10_000_000e18,
            uint256(1_000_000e18) / 1 days
        );

        rateLimits.setRateLimitData(
            makeAddressKey(mainnetController.LIMIT_FARM_WITHDRAW(), FARM),
            10_000_000e18,
            uint256(1_000_000e6) / 1 days
        );

        vm.stopPrank();
    }

    function _getBlock() internal override pure returns (uint256) {
        return 22982805;  // July 23, 2025
    }

}

contract MainnetController_Farm_Deposit_Tests is Farm_TestBase {

    function test_depositToFarm_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.depositToFarm(FARM, 1_000_000e18);
    }

    function test_depositToFarm_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.depositToFarm(FARM, 1_000_000e18);
    }

    function test_depositToFarm_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.depositToFarm(makeAddr("fake-farm"), 0);
    }

    function test_depositToFarm_rateLimitsBoundary() external {
        bytes32 key = makeAddressKey(mainnetController.LIMIT_FARM_DEPOSIT(), FARM);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e18, uint256(1_000_000e18) / 1 days);

        deal(Ethereum.USDS, almProxy, 1_000_000e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        mainnetController.depositToFarm(FARM, 1_000_000e18 + 1);

        vm.prank(RELAYER);
        mainnetController.depositToFarm(FARM, 1_000_000e18);
    }

    function test_depositToFarm() external {
        bytes32 depositKey = makeAddressKey(mainnetController.LIMIT_FARM_DEPOSIT(), FARM);

        deal(Ethereum.USDS, almProxy, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18);

        assertEq(USDS.balanceOf(almProxy),             1_000_000e18);
        assertEq(IERC20Like(FARM).balanceOf(almProxy), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.depositToFarm(FARM, 1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 9_000_000e18);

        assertEq(USDS.balanceOf(almProxy),             0);
        assertEq(IERC20Like(FARM).balanceOf(almProxy), 1_000_000e18);
    }

}

contract MainnetController_Farm_Withdraw_Tests is Farm_TestBase {

    function test_withdrawFromFarm_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.withdrawFromFarm(FARM, 1_000_000e18);
    }

    function test_withdrawFromFarm_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.withdrawFromFarm(FARM, 1_000_000e18);
    }

    function test_withdrawFromFarm_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.withdrawFromFarm(makeAddr("fake-farm"), 0);
    }

    function test_withdrawFromFarm_rateLimitsBoundary() external {
        bytes32 key = makeAddressKey(mainnetController.LIMIT_FARM_WITHDRAW(), FARM);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e18, uint256(1_000_000e18) / 1 days);

        deal(Ethereum.USDS, almProxy, 1_000_000e18);

        vm.startPrank(RELAYER);

        mainnetController.depositToFarm(FARM, 1_000_000e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.withdrawFromFarm(FARM, 1_000_000e18 + 1);

        mainnetController.withdrawFromFarm(FARM, 1_000_000e18);

        vm.stopPrank();
    }

    function test_withdrawFromFarm() external {
        bytes32 withdrawKey = makeAddressKey(mainnetController.LIMIT_FARM_WITHDRAW(), FARM);

        deal(Ethereum.USDS, almProxy, 1_000_000e18);

        vm.prank(RELAYER);
        mainnetController.depositToFarm(FARM, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 10_000_000e18);

        assertEq(USDS.balanceOf(almProxy),                     0);
        assertEq(IERC20Like(FARM).balanceOf(almProxy),         1_000_000e18);
        assertEq(IERC20Like(Ethereum.SPK).balanceOf(almProxy), 0);

        skip(1 days);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.withdrawFromFarm(FARM, 1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 9_000_000e18);

        assertEq(USDS.balanceOf(almProxy),                     1_000_000e18);
        assertEq(IERC20Like(FARM).balanceOf(almProxy),         0);
        assertEq(IERC20Like(Ethereum.SPK).balanceOf(almProxy), 2930.857045118398e18);
    }

}
