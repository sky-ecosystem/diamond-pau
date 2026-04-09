// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { IBasinFacet } from "../../src/facets/basin/IBasinFacet.sol";

import { GroveBasin }        from "../../lib/grove-basin/src/GroveBasin.sol";
import { FixedRateProvider } from "../../lib/grove-basin/src/rate-providers/FixedRateProvider.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

}

abstract contract Basin_TestBase is ForkTestBase {

    GroveBasin internal groveBasin;

    uint256 internal constant SEED_AMOUNT = 1_000e18;

    function setUp() public virtual override {
        super.setUp();

        // Deploy fixed rate providers (1:1 USD pricing, never stale).
        FixedRateProvider rateProvider = new FixedRateProvider(1e27);

        // Deploy GroveBasin with almProxy as liquidityProvider.
        groveBasin = new GroveBasin(
            address(this),          // owner
            address(almProxy),      // liquidityProvider
            Ethereum.USDC,          // swapToken
            Ethereum.USDS,          // collateralToken (what we test with)
            Ethereum.DAI,           // creditToken
            address(rateProvider),
            address(rateProvider),
            address(rateProvider)
        );

        // Seed the basin with `depositInitial`.
        deal(Ethereum.USDS, address(this), SEED_AMOUNT);
        IERC20Like(Ethereum.USDS).approve(address(groveBasin), SEED_AMOUNT);
        groveBasin.depositInitial(Ethereum.USDS, SEED_AMOUNT);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                mainnetController.LIMIT_BASIN_DEPOSIT(),
                Ethereum.USDS,
                address(groveBasin)
            ),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                mainnetController.LIMIT_BASIN_WITHDRAW(),
                Ethereum.USDS,
                address(groveBasin)
            ),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        vm.stopPrank();

        vm.label(address(groveBasin), "GroveBasin");
    }

    /**********************************************************************************************/
    /*** Helpers                                                                                ***/
    /**********************************************************************************************/

    function _depositToBasin(uint256 amount) internal {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(groveBasin)
        );

        uint256 currentRateLimit = rateLimits.getCurrentRateLimit(key);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, amount, uint256(1_000_000e18) / 4 hours);

        deal(Ethereum.USDS, address(almProxy), amount);
        vm.prank(relayer);
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, amount);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, currentRateLimit, uint256(1_000_000e18) / 4 hours);
    }

}

contract MainnetController_Basin_Deposit_Tests is Basin_TestBase {

    function test_depositBasin_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_zeroMaxAmount() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(groveBasin)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_depositBasin_rateLimitBoundary() external {
        deal(Ethereum.USDS, address(almProxy), 5_000_000e18 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 5_000_000e18 + 1);

        vm.prank(relayer);
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 5_000_000e18);
    }

    function test_depositBasin() external {
        uint256 depositAmount = 1_000_000e18;

        deal(Ethereum.USDS, address(almProxy), depositAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),   depositAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(groveBasin)), SEED_AMOUNT);

        assertEq(IERC20Like(Ethereum.USDS).allowance(address(almProxy), address(groveBasin)), 0);

        uint256 expectedShares = groveBasin.previewDeposit(Ethereum.USDS, depositAmount);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit IBasinFacet.BasinDeposit(address(groveBasin), Ethereum.USDS, depositAmount, depositAmount);

        vm.prank(relayer);
        uint256 shares = mainnetController.depositBasin(
            address(groveBasin),
            Ethereum.USDS,
            depositAmount
        );

        _assertReentrancyGuardWrittenToTwice();

        assertEq(shares, expectedShares);
        assertGt(shares, 0);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),   0);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(groveBasin)), depositAmount + SEED_AMOUNT);

        assertEq(IERC20Like(Ethereum.USDS).allowance(address(almProxy), address(groveBasin)), 0);
    }

    function test_depositBasin_rateLimited() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_DEPOSIT(),
            Ethereum.USDS,
            address(groveBasin)
        );

        deal(Ethereum.USDS, address(almProxy), 5_000_000e18);

        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);

        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);

        skip(1 hours);

        deal(Ethereum.USDS, address(almProxy), 4_249_999.999999999999998400e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_249_999.999999999999998400e18);

        mainnetController.depositBasin(
            address(groveBasin),
            Ethereum.USDS,
            4_249_999.999999999999998400e18
        );

        assertEq(rateLimits.getCurrentRateLimit(key), 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.depositBasin(address(groveBasin), Ethereum.USDS, 1);

        vm.stopPrank();
    }

}

contract MainnetController_Basin_Withdraw_Tests is Basin_TestBase {

    function test_withdrawBasin_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_zeroMaxAmount() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(groveBasin)
        );

        // Deposit first so the proxy has shares and the basin has USDS
        _depositToBasin(1e18);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 1e18);
    }

    function test_withdrawBasin_rateLimitBoundary() external {
        // Deposit enough to cover the boundary test
        _depositToBasin(5_000_000e18 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 5_000_000e18 + 1);

        vm.prank(relayer);
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 5_000_000e18);
    }

    function test_withdrawBasin() external {
        uint256 withdrawAmount = 1_000_000e18;

        // Deposit first so the proxy has shares
        _depositToBasin(withdrawAmount);

        uint256 proxyBalBefore = IERC20Like(Ethereum.USDS).balanceOf(address(almProxy));
        uint256 basinBalBefore = IERC20Like(Ethereum.USDS).balanceOf(address(groveBasin));

        assertEq(proxyBalBefore, 0);
        assertGe(basinBalBefore, withdrawAmount);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit IBasinFacet.BasinWithdraw(address(groveBasin), Ethereum.USDS, withdrawAmount);

        vm.prank(relayer);
        uint256 assetsWithdrawn = mainnetController.withdrawBasin(
            address(groveBasin),
            Ethereum.USDS,
            withdrawAmount
        );

        _assertReentrancyGuardWrittenToTwice();

        assertEq(assetsWithdrawn, withdrawAmount);

        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(almProxy)),   withdrawAmount);
        assertEq(IERC20Like(Ethereum.USDS).balanceOf(address(groveBasin)), basinBalBefore - withdrawAmount);
    }

    function test_withdrawBasin_rateLimited() external {
        bytes32 key = makeAddressAddressKey(
            mainnetController.LIMIT_BASIN_WITHDRAW(),
            Ethereum.USDS,
            address(groveBasin)
        );

        // Deposit enough to cover all withdrawals: 1M + ~4.25M = ~5.25M
        _depositToBasin(5_000_000e18 + 250_000e18);

        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e18);

        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_249_999.999999999999998400e18);

        mainnetController.withdrawBasin(
            address(groveBasin),
            Ethereum.USDS,
            4_249_999.999999999999998400e18
        );

        assertEq(rateLimits.getCurrentRateLimit(key), 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.withdrawBasin(address(groveBasin), Ethereum.USDS, 1);

        vm.stopPrank();
    }

}
