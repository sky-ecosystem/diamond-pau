// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { MockBasin } from "../mocks/MockBasin.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

}

abstract contract Basin_TestBase is ForkTestBase {

    uint256 internal constant BASIN_MAX_AMOUNT = 5_000_000e18;
    uint256 internal constant BASIN_SLOPE      = uint256(1_000_000e18) / 4 hours;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                mainnetController.LIMIT_BASIN_DEPOSIT(),
                Ethereum.USDS,
                address(mockBasin)
            ),
            BASIN_MAX_AMOUNT,
            BASIN_SLOPE
        );

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                mainnetController.LIMIT_BASIN_WITHDRAW(),
                Ethereum.USDS,
                address(mockBasin)
            ),
            BASIN_MAX_AMOUNT,
            BASIN_SLOPE
        );

        vm.stopPrank();
    }

}

contract MainnetController_Basin_Deposit_Tests is Basin_TestBase {

    function test_depositBasin_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_zeroMaxAmount() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(mockBasin)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(almProxy), BASIN_MAX_AMOUNT + 1e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, BASIN_MAX_AMOUNT + 1e18);

        vm.prank(relayer);
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, BASIN_MAX_AMOUNT);
    }

    function test_depositBasin() external {
        uint256 depositAmount = 1_000_000e18;

        deal(Ethereum.USDS, address(almProxy), depositAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  depositAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), 0);

        assertEq(IERC20Like(Ethereum.USDS).allowance(address(almProxy), address(mockBasin)), 0);

        vm.record();

        vm.prank(relayer);
        uint256 shares = mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, depositAmount);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(shares, depositAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  0);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), depositAmount);

        assertEq(IERC20Like(Ethereum.USDS).allowance(address(almProxy), address(mockBasin)), 0);
    }

    function test_depositBasin_customShares() external {
        uint256 depositAmount = 1_000_000e18;
        uint256 customShares  = 500_000e18;

        mockBasin.setDepositShares(customShares);
        deal(Ethereum.USDS, address(almProxy), depositAmount);

        vm.prank(relayer);
        uint256 shares = mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, depositAmount);

        assertEq(shares, customShares);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  0);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), depositAmount);
    }

    function test_depositBasin_rateLimited() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(mockBasin)
        );

        deal(Ethereum.USDS, address(almProxy), BASIN_MAX_AMOUNT);

        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), BASIN_MAX_AMOUNT);

        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);

        skip(1 hours);

        uint256 currentLimit = rateLimits.getCurrentRateLimit(key);

        deal(Ethereum.USDS, address(almProxy), currentLimit);

        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, currentLimit);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1);

        vm.stopPrank();
    }

}

contract MainnetController_Basin_Withdraw_Tests is Basin_TestBase {

    function test_withdrawBasin_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_zeroMaxAmount() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(mockBasin)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        // Withdraw executes before rate limit check, so need tokens in the mock
        deal(Ethereum.USDS, address(mockBasin), 1e18);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(mockBasin), BASIN_MAX_AMOUNT + 1e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, BASIN_MAX_AMOUNT + 1e18);

        vm.prank(relayer);
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, BASIN_MAX_AMOUNT);
    }

    function test_withdrawBasin() external {
        uint256 withdrawAmount = 1_000_000e18;

        deal(Ethereum.USDS, address(mockBasin), withdrawAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  0);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), withdrawAmount);

        vm.record();

        vm.prank(relayer);
        uint256 assetsWithdrawn = mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, withdrawAmount);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(assetsWithdrawn, withdrawAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  withdrawAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), 0);
    }

    function test_withdrawBasin_customAmount() external {
        uint256 maxAmount    = 1_000_000e18;
        uint256 customAmount = 500_000e18;

        mockBasin.setWithdrawAmount(customAmount);
        deal(Ethereum.USDS, address(mockBasin), customAmount);

        vm.prank(relayer);
        uint256 assetsWithdrawn = mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, maxAmount);

        assertEq(assetsWithdrawn, customAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),  customAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(mockBasin)), 0);
    }

    function test_withdrawBasin_rateLimited() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(mockBasin)
        );

        deal(Ethereum.USDS, address(mockBasin), BASIN_MAX_AMOUNT);

        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), BASIN_MAX_AMOUNT);

        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);

        skip(1 hours);

        uint256 currentLimit = rateLimits.getCurrentRateLimit(key);

        deal(Ethereum.USDS, address(mockBasin), currentLimit);

        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, currentLimit);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);

        deal(Ethereum.USDS, address(mockBasin), 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1);

        vm.stopPrank();
    }

}

contract MainnetController_Basin_RateLimitIsolation_Tests is Basin_TestBase {

    MockBasin internal mockBasin2;

    bytes32 internal depositKey1;
    bytes32 internal depositKey2;
    bytes32 internal withdrawKey1;
    bytes32 internal withdrawKey2;

    function setUp() public override {
        super.setUp();

        mockBasin2 = new MockBasin();
        vm.label(address(mockBasin2), "MockBasin2");

        depositKey1 = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(mockBasin)
        );
        depositKey2 = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(mockBasin2)
        );
        withdrawKey1 = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(mockBasin)
        );
        withdrawKey2 = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(mockBasin2)
        );

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey2,  BASIN_MAX_AMOUNT, BASIN_SLOPE);
        rateLimits.setRateLimitData(withdrawKey2, BASIN_MAX_AMOUNT, BASIN_SLOPE);
        vm.stopPrank();
    }

    function test_rateLimitKeys_areDifferent() external view {
        assertTrue(depositKey1 != depositKey2);
        assertTrue(withdrawKey1 != withdrawKey2);
    }

    function test_depositBasin_rateLimitIsolation() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey1), BASIN_MAX_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(depositKey2), BASIN_MAX_AMOUNT);

        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        vm.prank(relayer);
        mainnetController.depositBasin(address(mockBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey1), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(depositKey2), BASIN_MAX_AMOUNT);
    }

    function test_withdrawBasin_rateLimitIsolation() external {
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey1), BASIN_MAX_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey2), BASIN_MAX_AMOUNT);

        deal(Ethereum.USDS, address(mockBasin), 1_000_000e18);

        vm.prank(relayer);
        mainnetController.withdrawBasin(address(mockBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(withdrawKey1), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey2), BASIN_MAX_AMOUNT);
    }

}
