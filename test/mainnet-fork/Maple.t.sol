// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressKey } from "../../src/RateLimitHelpers.sol";

import {
    IMapleTokenExtendedLike,
    IPermissionManagerLike,
    IPoolManagerLike,
    IWithdrawalManagerLike
} from "../interfaces/Maple.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

}

abstract contract Maple_TestBase is ForkTestBase {

    IERC20Like internal constant USDC = IERC20Like(Ethereum.USDC);

    IMapleTokenExtendedLike internal constant SYRUP_USDC = IMapleTokenExtendedLike(Ethereum.SYRUP_USDC);

    IPermissionManagerLike internal constant PERMISSION_MANAGER
        = IPermissionManagerLike(0xBe10aDcE8B6E3E02Db384E7FaDA5395DD113D8b3);

    uint256 internal syrupConvertedAssets;
    uint256 internal syrupConvertedShares;

    uint256 internal usdcBalanceOfSyrupUSDC;

    uint256 internal syrupTotalAssets;
    uint256 internal syrupTotalSupply;

    bytes32 internal depositKey;
    bytes32 internal redeemKey;

    function setUp() override public {
        super.setUp();

        depositKey = makeAddressKey(mainnetController.LIMIT_4626_DEPOSIT(), Ethereum.SYRUP_USDC);
        redeemKey  = makeAddressKey(mainnetController.LIMIT_MAPLE_REDEEM(), Ethereum.SYRUP_USDC);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 1_000_000e6, uint256(1_000_000e6) / 1 days);
        rateLimits.setRateLimitData(redeemKey,  1_000_000e6, uint256(1_000_000e6) / 1 days);
        mainnetController.setMaxExchangeRate(Ethereum.SYRUP_USDC, SYRUP_USDC.convertToShares(1e18), 2e18);
        vm.stopPrank();

        // Maple onboarding process
        address[] memory lenders  = new address[](1);
        bool[]    memory booleans = new bool[](1);

        lenders[0]  = almProxy;
        booleans[0] = true;

        vm.startPrank(PERMISSION_MANAGER.admin());
        PERMISSION_MANAGER.setLenderAllowlist(
            SYRUP_USDC.manager(),
            lenders,
            booleans
        );
        vm.stopPrank();

        syrupConvertedAssets = SYRUP_USDC.convertToAssets(1_000_000e6);
        syrupConvertedShares = SYRUP_USDC.convertToShares(1_000_000e6);

        syrupTotalAssets = SYRUP_USDC.totalAssets();
        syrupTotalSupply = SYRUP_USDC.totalSupply();

        usdcBalanceOfSyrupUSDC = USDC.balanceOf(Ethereum.SYRUP_USDC);

        assertEq(syrupConvertedAssets, 1_066_100.425881e6);
        assertEq(syrupConvertedShares, 937_997.936895e6);

        assertEq(syrupTotalAssets, 59_578_045.544596e6);
        assertEq(syrupTotalSupply, 55_884_083.805100e6);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 21570000;  // Jan 7, 2024
    }

}

contract MainnetController_ERC4626_Maple_Deposit_Tests is Maple_TestBase {

    function test_depositERC4626_maple_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);
    }

    function test_depositERC4626_maple_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);
    }

    function test_depositERC4626_maple_rateLimitBoundary() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6 + 1, 0);

        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);
    }

    function test_depositERC4626_maple_exchangeRateTooHigh() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.setMaxExchangeRate(Ethereum.SYRUP_USDC, SYRUP_USDC.convertToShares(1_000_000e6), 1_000_000e6 - 1);
        vm.stopPrank();

        vm.expectRevert("ERC4626Lib/exchange-rate-too-high");
        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.setMaxExchangeRate(Ethereum.SYRUP_USDC, SYRUP_USDC.convertToShares(1_000_000e6), 1_000_000e6);
        vm.stopPrank();

        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);
    }

    function test_depositERC4626_maple_zeroExchangeRate() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.setMaxExchangeRate(Ethereum.SYRUP_USDC, 0, 0);

        vm.expectRevert("ERC4626Lib/exchange-rate-too-high");
        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);
    }

    function test_depositERC4626_maple_minSharesOutNotMetBoundary() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        uint256 overBoundaryShares = SYRUP_USDC.convertToShares(1_000_000e6 + 1);
        uint256 atBoundaryShares   = SYRUP_USDC.convertToShares(1_000_000e6);

        vm.expectRevert("ERC4626Lib/min-shares-out-not-met");
        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, overBoundaryShares);

        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, atBoundaryShares);
    }

    function test_depositERC4626_maple() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 1_000_000e6);

        assertEq(USDC.balanceOf(almProxy),                   1_000_000e6);
        assertEq(USDC.balanceOf(address(mainnetController)), 0);
        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC),        usdcBalanceOfSyrupUSDC);

        assertEq(USDC.allowance(almProxy, Ethereum.SYRUP_USDC),  0);

        assertEq(SYRUP_USDC.totalSupply(),       syrupTotalSupply);
        assertEq(SYRUP_USDC.totalAssets(),       syrupTotalAssets);
        assertEq(SYRUP_USDC.balanceOf(almProxy), 0);

        vm.prank(RELAYER);
        uint256 shares = mainnetController.depositERC4626(
            Ethereum.SYRUP_USDC,
            1_000_000e6,
            syrupConvertedShares
        );

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 0);

        assertEq(shares, syrupConvertedShares);

        assertEq(USDC.balanceOf(almProxy),                   0);
        assertEq(USDC.balanceOf(address(mainnetController)), 0);
        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC),        usdcBalanceOfSyrupUSDC + 1_000_000e6);

        assertEq(USDC.allowance(almProxy, Ethereum.SYRUP_USDC), 0);

        assertEq(SYRUP_USDC.totalSupply(),       syrupTotalSupply + shares);
        assertEq(SYRUP_USDC.totalAssets(),       syrupTotalAssets + 1_000_000e6);
        assertEq(SYRUP_USDC.balanceOf(almProxy), shares);
    }

}

contract MainnetController_Maple_RequestRedemption_Tests is Maple_TestBase {

    function test_requestMapleRedemption_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, 1_000_000e6);
    }

    function test_requestMapleRedemption_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, 1_000_000e6);
    }

    function test_requestMapleRedemption_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(redeemKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, 1_000_000e6);
    }

    function test_requestMapleRedemption_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 5_000_000e6, uint256(1_000_000e6) / 1 days);

        deal(Ethereum.USDC, almProxy, 5_000_000e6);

        vm.prank(RELAYER);
        mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 5_000_000e6, 0);

        uint256 overBoundaryShares = SYRUP_USDC.convertToShares(1_000_000e6 + 2);  // Rounding
        uint256 atBoundaryShares   = SYRUP_USDC.convertToShares(1_000_000e6 + 1);  // Rounding

        assertEq(SYRUP_USDC.convertToAssets(overBoundaryShares), 1_000_000e6 + 1);
        assertEq(SYRUP_USDC.convertToAssets(atBoundaryShares),   1_000_000e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, overBoundaryShares);

        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, atBoundaryShares);
    }

    function test_requestMapleRedemption() external {
        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        vm.prank(RELAYER);
        uint256 proxyShares = mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);

        uint256 redeemAssets = SYRUP_USDC.convertToAssets(proxyShares);

        address withdrawalManager   = IPoolManagerLike(SYRUP_USDC.manager()).withdrawalManager();
        uint256 totalEscrowedShares = SYRUP_USDC.balanceOf(withdrawalManager);

        assertEq(rateLimits.getCurrentRateLimit(redeemKey), 1_000_000e6);

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager),           totalEscrowedShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),                    proxyShares);
        assertEq(SYRUP_USDC.allowance(almProxy, withdrawalManager), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, proxyShares);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(redeemKey), 1_000_000e6 - redeemAssets);

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager),           totalEscrowedShares + proxyShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),                    0);
        assertEq(SYRUP_USDC.allowance(almProxy, withdrawalManager), 0);
    }
}

contract MainnetController_Maple_CancelRedemption_Tests is Maple_TestBase {

    function test_cancelMapleRedemption_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.cancelMapleRedemption(Ethereum.SYRUP_USDC, 1_000_000e6);
    }

    function test_cancelMapleRedemption_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        mainnetController.cancelMapleRedemption(Ethereum.SYRUP_USDC, 1_000_000e6);
    }

    function test_cancelMapleRedemption_invalidMapleToken() external {
        vm.expectRevert("MapleLib/invalid-action");
        vm.prank(RELAYER);
        mainnetController.cancelMapleRedemption(makeAddr("fake-SYRUP"), 1_000_000e6);
    }

    function test_cancelMapleRedemption() external {
        address withdrawalManager   = IPoolManagerLike(SYRUP_USDC.manager()).withdrawalManager();
        uint256 totalEscrowedShares = SYRUP_USDC.balanceOf(withdrawalManager);

        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        vm.startPrank(RELAYER);

        uint256 proxyShares = mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);

        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, proxyShares);

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager), totalEscrowedShares + proxyShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),          0);

        vm.record();

        mainnetController.cancelMapleRedemption(Ethereum.SYRUP_USDC, proxyShares);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager), totalEscrowedShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),          proxyShares);

        vm.stopPrank();
    }

}

contract MainnetController_Maple_E2ETests is Maple_TestBase {

    function test_e2e_mapleDepositAndRedeem() external {
        // Increase withdraw rate limit so interest can be accrued
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(redeemKey, 2_000_000e6, uint256(1_000_000e6) / 1 days);

        deal(Ethereum.USDC, almProxy, 1_000_000e6);

        // --- Step 1: Deposit USDC into Maple ---

        assertEq(USDC.balanceOf(almProxy),                   1_000_000e6);
        assertEq(USDC.balanceOf(address(mainnetController)), 0);
        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC),        usdcBalanceOfSyrupUSDC);

        assertEq(USDC.allowance(almProxy, Ethereum.SYRUP_USDC),  0);

        assertEq(SYRUP_USDC.totalSupply(),                syrupTotalSupply);
        assertEq(SYRUP_USDC.totalAssets(),                syrupTotalAssets);
        assertEq(SYRUP_USDC.balanceOf(almProxy), 0);

        vm.prank(RELAYER);
        uint256 proxyShares = mainnetController.depositERC4626(Ethereum.SYRUP_USDC, 1_000_000e6, 0);

        assertEq(proxyShares, syrupConvertedShares);

        assertEq(USDC.balanceOf(almProxy),                   0);
        assertEq(USDC.balanceOf(address(mainnetController)), 0);
        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC),        usdcBalanceOfSyrupUSDC + 1_000_000e6);

        assertEq(USDC.allowance(almProxy, Ethereum.SYRUP_USDC), 0);

        assertEq(SYRUP_USDC.totalSupply(),       syrupTotalSupply + proxyShares);
        assertEq(SYRUP_USDC.totalAssets(),       syrupTotalAssets + 1_000_000e6);
        assertEq(SYRUP_USDC.balanceOf(almProxy), syrupConvertedShares);

        // --- Step 2: Request Redeem ---

        skip(1 days);  // Warp to accrue interest

        address withdrawalManager   = IPoolManagerLike(SYRUP_USDC.manager()).withdrawalManager();
        uint256 totalEscrowedShares = SYRUP_USDC.balanceOf(withdrawalManager);

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager),           totalEscrowedShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),                    proxyShares);
        assertEq(SYRUP_USDC.allowance(almProxy, withdrawalManager), 0);

        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(Ethereum.SYRUP_USDC, proxyShares);

        assertEq(SYRUP_USDC.balanceOf(withdrawalManager),           totalEscrowedShares + proxyShares);
        assertEq(SYRUP_USDC.balanceOf(almProxy),                    0);
        assertEq(SYRUP_USDC.allowance(almProxy, withdrawalManager), 0);

        // --- Step 3: Fulfill Redeem (done by Maple) ---

        skip(1 days);  // Warp to accrue more interest

        uint256 totalAssets    = SYRUP_USDC.totalAssets();
        uint256 withdrawAssets = SYRUP_USDC.convertToAssets(proxyShares);
        usdcBalanceOfSyrupUSDC = USDC.balanceOf(Ethereum.SYRUP_USDC);

        assertGt(totalAssets, syrupTotalAssets + 1_000_000e6);  // Interest accrued

        assertEq(withdrawAssets, 1_000_423.216342e6);  // Interest accrued

        assertEq(SYRUP_USDC.totalSupply(),                syrupTotalSupply + proxyShares);
        assertEq(SYRUP_USDC.totalAssets(),                totalAssets);
        assertEq(SYRUP_USDC.balanceOf(withdrawalManager), totalEscrowedShares + proxyShares);

        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC), usdcBalanceOfSyrupUSDC);
        assertEq(USDC.balanceOf(almProxy),            0);

        // NOTE: `proxyShares` can be used in this case because almProxy is the only account using the
        //       `withdrawalManager` at this fork block. Usually `processRedemptions` requires
        //       `maxSharesToProcess` to include the shares of all accounts ahead of almProxy in
        //       queue plus almProxy's shares.
        vm.prank(IPoolManagerLike(SYRUP_USDC.manager()).poolDelegate());
        IWithdrawalManagerLike(withdrawalManager).processRedemptions(proxyShares);

        assertEq(SYRUP_USDC.totalSupply(),                syrupTotalSupply);
        assertEq(SYRUP_USDC.totalAssets(),                totalAssets - withdrawAssets);
        assertEq(SYRUP_USDC.balanceOf(withdrawalManager), totalEscrowedShares);

        assertEq(USDC.balanceOf(Ethereum.SYRUP_USDC), usdcBalanceOfSyrupUSDC - withdrawAssets);
        assertEq(USDC.balanceOf(almProxy),            withdrawAssets);
    }
}
