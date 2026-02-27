// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Base as SparkBase } from "../../lib/spark-address-registry/src/Base.sol";
import { Base as GroveBase } from "../../lib/grove-address-registry/src/Base.sol";

import { IPendleMarket, ISY, IYT } from "../../src/libraries/PendleLib.sol";

import { RateLimitHelpers } from "../../src/RateLimitHelpers.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

contract PendleTestBase is ForkTestBase {

    // USDe 11 Dec 2025 market
    IPendleMarket pendleMarket = IPendleMarket(0x8991847176b1D187e403dd92a4E55fC8d7684538);

    address PT_WHALE = 0x26b6B3e01fB0ba398e25b1ADbE295036A32E696c;

    bytes32 redeemKey;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(GroveBase.PENDLE_ROUTER);

        redeemKey = RateLimitHelpers.makeAddressKey(
            foreignController.LIMIT_PENDLE_PT_REDEEM(),
            address(pendleMarket)
        );

        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, 10_000_000e18, uint256(10_000_000e18) / 1 days);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 37_589_683;
    }

}

contract ForeignControllerSetPendleRouterFailureTests is PendleTestBase {

    function test_setPendleRouter_reentrancy() public {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.setPendleRouter(GroveBase.PENDLE_ROUTER);
    }

    function test_setPendleRouter_notAdmin() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setPendleRouter(GroveBase.PENDLE_ROUTER);
    }

}

contract ForeignControllerSetPendleRouterSuccessTests is PendleTestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(address(0));
    }

    function test_setPendleRouter_success() public {
        assertEq(foreignController.pendleRouter(), address(0));
        
        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(GroveBase.PENDLE_ROUTER);

        assertEq(foreignController.pendleRouter(), GroveBase.PENDLE_ROUTER);
    }

}

contract ForeignControllerRedeemFailurePendleTests is PendleTestBase {

    function test_redeemPendlePT_pendleRouterNotSet() public {
        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(address(0));

        vm.prank(relayer);
        vm.expectRevert("PendleLib/pendle-router-not-set");
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, 1);
    }

    function test_redeemPendlePT_notRelayer() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, 1);
    }

    function test_redeemPendlePT_marketNotExpired() public {
        vm.warp(pendleMarket.expiry() - 1);

        vm.prank(relayer);
        vm.expectRevert("PendleLib/market-not-expired");
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, 1);
    }

    function test_redeemPendlePT_zeroMaxAmount() public {
        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, 0, 0);

        (, address pt,) = pendleMarket.readTokens();
        vm.prank(PT_WHALE);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);

        vm.warp(pendleMarket.expiry());

        vm.prank(relayer);
        vm.expectRevert("RateLimits/zero-maxAmount");
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, 1);
    }

    function test_redeemPendlePT_rateLimitsBoundary() public {
        (, address pt, address yt) = pendleMarket.readTokens();
        vm.prank(PT_WHALE);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);

        vm.warp(pendleMarket.expiry());

        uint256 pyIndexCurrent = IYT(yt).pyIndexCurrent();
        uint256 exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, exactAmountOut - 1, 1);

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, 1);
    }

    function test_redeemPendlePT_insufficientBalance() public {
        (, address pt,) = pendleMarket.readTokens();
        vm.prank(PT_WHALE);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);

        vm.warp(pendleMarket.expiry());

        vm.prank(relayer);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        foreignController.redeemPendlePT(address(pendleMarket), 100_000e18 + 1, 1);
    }

    function test_redeemPendlePT_amountTooSmall() public {
        (, address pt,) = pendleMarket.readTokens();
        vm.prank(PT_WHALE);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);

        vm.warp(pendleMarket.expiry());

        vm.prank(relayer);
        vm.expectRevert("panic: arithmetic underflow or overflow (0x11)");
        foreignController.redeemPendlePT(address(pendleMarket), 4, 1);
    }

    function test_redeemPendlePT_minAmountOutNotSet() public {
        vm.warp(pendleMarket.expiry());

        vm.prank(relayer);
        vm.expectRevert("PendleLib/min-amount-out-not-set");
        foreignController.redeemPendlePT(address(pendleMarket), 100_000e18, 0);
    }

    function test_redeemPendlePT_minAmountOutNotMet() public {
        (, address pt, address yt) = pendleMarket.readTokens();
        vm.prank(PT_WHALE);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);

        vm.warp(pendleMarket.expiry());

        uint256 pyIndexCurrent = IYT(yt).pyIndexCurrent();
        uint256 exactAmountOut = 100_000e18 * 1e18 / pyIndexCurrent; // Exact at this particular point in time

        vm.prank(relayer);
        vm.expectRevert("PendleLib/min-amount-not-met");
        foreignController.redeemPendlePT(address(pendleMarket), 100_000e18, exactAmountOut + 1);

        vm.prank(relayer);
        foreignController.redeemPendlePT(address(pendleMarket), 100_000e18, exactAmountOut);

    }

}

contract ForeignControllerRedeemSuccessPendleTests is PendleTestBase {

    function test_redeemPendlePT() public {
        // Default Pendle market used in tests is already a sUSDe market

        address ptDonor = PT_WHALE;

        (address sy, address pt, address yt) = pendleMarket.readTokens();
        IERC20 yieldToken = IERC20(ISY(sy).yieldToken());

        vm.startPrank(ptDonor);
        IERC20(pt).transfer((address(almProxy)), 100_000e18);
        vm.stopPrank();

        assertEq(IERC20(pt).balanceOf(address(almProxy)),         100_000e18);
        assertEq(IERC20(yieldToken).balanceOf(address(almProxy)), 0);

        vm.warp(pendleMarket.expiry());

        uint256 pyIndexCurrent = IYT(yt).pyIndexCurrent();
        uint256 exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(relayer);
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, exactAmountOut);

        assertEq(IERC20(pt).balanceOf(address(almProxy)), 50_000e18);
        assertEq(IERC20(yieldToken).balanceOf(address(almProxy)), 50_000e18 * 1e18 / pyIndexCurrent);

        vm.warp(block.timestamp + 14 days);

        pyIndexCurrent = IYT(yt).pyIndexCurrent();
        exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(relayer);
        foreignController.redeemPendlePT(address(pendleMarket), 50_000e18, exactAmountOut);

        assertEq(IERC20(pt).balanceOf(address(almProxy)), 0);
        assertEq(IERC20(yieldToken).balanceOf(address(almProxy)), 100_000e18 * 1e18 / pyIndexCurrent);
    }

}
