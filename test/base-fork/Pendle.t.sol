// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Base as SparkBase } from "../../lib/spark-address-registry/src/Base.sol";
import { Base as GroveBase } from "../../lib/grove-address-registry/src/Base.sol";

import { makeAddressKey } from "../../src/RateLimitHelpers.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256 balance);

}

interface IPendleMarketLike {

    function expiry() external view returns (uint256);

    function readTokens() external view returns (address sy, address pt, address yt);

}

interface ISYLike {

    function yieldToken() external view returns (address);

}

interface IYTLike {

    function pyIndexCurrent() external returns (uint256);

}

abstract contract Pendle_TestBase is ForkTestBase {

    // USDe 11 Dec 2025 market
    IPendleMarketLike internal constant MARKET = IPendleMarketLike(0x8991847176b1D187e403dd92a4E55fC8d7684538);

    address internal constant PT_WHALE = 0x26b6B3e01fB0ba398e25b1ADbE295036A32E696c;

    bytes32 internal redeemKey;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(GroveBase.PENDLE_ROUTER);

        redeemKey = makeAddressKey(
            foreignController.LIMIT_PENDLE_PT_REDEEM(),
            address(MARKET)
        );

        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, 10_000_000e18, uint256(10_000_000e18) / 1 days);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 37_589_683;
    }

}

contract ForeignController_Pendle_RedeemPT_Tests is Pendle_TestBase {

    function test_redeemPendlePT_pendleRouterNotSet() external {
        vm.prank(SparkBase.SPARK_EXECUTOR);
        foreignController.setPendleRouter(address(0));

        vm.expectRevert("PendleLib/pendle-router-not-set");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, 1);
    }

    function test_redeemPendlePT_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, 1);
    }

    function test_redeemPendlePT_marketNotExpired() external {
        vm.warp(MARKET.expiry() - 1);

        vm.expectRevert("PendleLib/market-not-expired");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, 1);
    }

    function test_redeemPendlePT_zeroMaxAmount() external {
        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, 0, 0);

        ( , address pt, ) = MARKET.readTokens();
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        vm.warp(MARKET.expiry());

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, 1);
    }

    function test_redeemPendlePT_rateLimitsBoundary() external {
        ( , address pt, address yt ) = MARKET.readTokens();
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        vm.warp(MARKET.expiry());

        uint256 pyIndexCurrent = IYTLike(yt).pyIndexCurrent();
        uint256 exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(SparkBase.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(redeemKey, exactAmountOut - 1, 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, 1);
    }

    function test_redeemPendlePT_insufficientBalance() external {
        ( , address pt, ) = MARKET.readTokens();
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        vm.warp(MARKET.expiry());

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 100_000e18 + 1, 1);
    }

    function test_redeemPendlePT_amountTooSmall() external {
        ( , address pt, ) = MARKET.readTokens();
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        vm.warp(MARKET.expiry());

        vm.expectRevert("panic: arithmetic underflow or overflow (0x11)");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 4, 1);
    }

    function test_redeemPendlePT_minAmountOutNotSet() external {
        vm.warp(MARKET.expiry());

        vm.expectRevert("PendleLib/min-amount-out-not-set");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 100_000e18, 0);
    }

    function test_redeemPendlePT_minAmountOutNotMet() external {
        ( , address pt, address yt ) = MARKET.readTokens();
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        vm.warp(MARKET.expiry());

        uint256 pyIndexCurrent = IYTLike(yt).pyIndexCurrent();
        uint256 exactAmountOut = 100_000e18 * 1e18 / pyIndexCurrent; // Exact at this particular point in time

        vm.expectRevert("PendleLib/min-amount-not-met");
        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 100_000e18, exactAmountOut + 1);

        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 100_000e18, exactAmountOut);

    }

    function test_redeemPendlePT() external {
        // Default Pendle market used in tests is already a sUSDe market

        address ptDonor = PT_WHALE;

        (address sy, address pt, address yt ) = MARKET.readTokens();
        IERC20Like yieldToken = IERC20Like(ISYLike(sy).yieldToken());

        vm.prank(ptDonor);
        IERC20Like(pt).transfer(almProxy, 100_000e18);

        assertEq(IERC20Like(pt).balanceOf(almProxy), 100_000e18);
        assertEq(yieldToken.balanceOf(almProxy),     0);

        vm.warp(MARKET.expiry());

        uint256 pyIndexCurrent = IYTLike(yt).pyIndexCurrent();
        uint256 exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, exactAmountOut);

        assertEq(IERC20Like(pt).balanceOf(almProxy), 50_000e18);
        assertEq(yieldToken.balanceOf(almProxy),     50_000e18 * 1e18 / pyIndexCurrent);

        vm.warp(block.timestamp + 14 days);

        pyIndexCurrent = IYTLike(yt).pyIndexCurrent();
        exactAmountOut = 50_000e18 * 1e18 / pyIndexCurrent;

        vm.prank(RELAYER);
        foreignController.redeemPendlePT(address(MARKET), 50_000e18, exactAmountOut);

        assertEq(IERC20Like(pt).balanceOf(almProxy), 0);
        assertEq(yieldToken.balanceOf(almProxy),     100_000e18 * 1e18 / pyIndexCurrent);
    }

}
