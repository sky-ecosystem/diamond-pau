// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { DataTypes } from "../../lib/aave-v3-origin/src/core/contracts/protocol/libraries/types/DataTypes.sol";

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Base } from "../../lib/spark-address-registry/src/Base.sol";

import { makeAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { IAaveFacet } from "../../src/facets/aave/IAaveFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface IAavePoolLike {

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16  referralCode,
        address onBehalfOf
    ) external;

    function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory);

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) external returns (uint256);

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

}

abstract contract AaveV3_TestBase is ForkTestBase {

    address internal constant ATOKEN_USDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;
    address internal constant POOL        = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    IERC20Like internal constant AUSDC = IERC20Like(ATOKEN_USDC);

    uint256 internal startingAUSDCBalance;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(Base.SPARK_EXECUTOR);

        // Borrow rate limits
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_BORROW(), ATOKEN_USDC),
            15_000e6,
            uint256(15_000e6) / 1 days
        );

        // Deposit rate limits
        // NOTE: Hit SUPPLY_CAP_EXCEEDED when using 25m
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_DEPOSIT(), ATOKEN_USDC),
            1_000_000e6,
            uint256(1_000_000e6) / 1 days
        );

        // Repay rate limits
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_REPAY(), ATOKEN_USDC),
            15_000e6,
            uint256(15_000e6) / 1 days
        );

        // Withdraw rate limits
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_WITHDRAW(), ATOKEN_USDC),
            1_000_000e6,
            uint256(5_000_000e6) / 1 days
        );

        // Max slippage
        foreignController.setAaveMaxSlippage(ATOKEN_USDC, 1e18 - 1e4);  // Rounding slippage

        vm.stopPrank();

        startingAUSDCBalance = usdcBase.balanceOf(ATOKEN_USDC);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 22841965;  // November 24, 2024
    }

    function _getDebtBalance(address underlying) internal view returns (uint256) {
        DataTypes.ReserveDataLegacy memory reserveData
            = IAavePoolLike(POOL).getReserveData(underlying);

        return IERC20Like(reserveData.variableDebtTokenAddress).balanceOf(address(almProxy));
    }

}

contract ForeignController_AaveV3_SetCollateral_Tests is AaveV3_TestBase {

    function setUp() public override {
        super.setUp();

        // Deposit USDC to be able to test setting collateral.
        deal(Base.USDC, address(almProxy), 1_000_000e6);

        // Initial deposit enables USDC as collateral.
        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
    }

    function test_setAaveCollateral_usdc() external {
        // Disable USDC collateral.
        vm.record();

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveCollateralSet(ATOKEN_USDC, false);

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveCollateral(ATOKEN_USDC, false);

        _assertReentrancyGuardWrittenToTwice();

        // Re-enable USDC collateral.
        vm.record();

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveCollateralSet(ATOKEN_USDC, true);

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveCollateral(ATOKEN_USDC, true);

        _assertReentrancyGuardWrittenToTwice();
    }

    function test_setAaveCollateral_disableAndBorrow() external {
        // Step-1: Disable USDC collateral.
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveCollateral(ATOKEN_USDC, false);

        // Step-2: Borrow fails with USDC collateral disabled.
        vm.expectRevert(abi.encode("34")); // SpecifiedCurrencyNotBorrowedByUser
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18);

        // Step-3: Re-enable USDC collateral.
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveCollateral(ATOKEN_USDC, true);

        // Step-4: Borrow succeeds with USDC collateral enabled.
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18);
    }

}

contract ForeignController_AaveV3_Borrow_Tests is AaveV3_TestBase {

    function setUp() public override {
        super.setUp();

        // Deposit USDC to be able to borrow.

        deal(Base.USDC, address(almProxy), 1_000_000e6);

        vm.startPrank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
        vm.stopPrank();
    }

    function test_borrowAave_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1.5e18);
    }

    function test_borrowAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1.5e18);
    }

    function test_borrowAave_invalidMinHealthFactorBoundary() external {
        vm.expectRevert("AaveFacet/invalid-min-health-factor");
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18 - 1);

        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18);
    }

    function test_borrowAave_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        foreignController.borrowAave(makeAddr("fake-token"), 1e6, 1e18);
    }

    function test_borrowAave_usdcRateLimitedBoundary() external {
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 15_000e6 + 1, 1e18);

        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 15_000e6, 1e18);
    }

    function test_borrowAave_usdcHealthFactorTooLowBoundary() external {
        vm.expectRevert("AaveFacet/health-factor-too-low");
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 78.000000000000000001e18);

        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 78e18);
    }

    function test_borrowAave_usdc_amountTooLow() external {
        // Mocking the borrow amount to be less than the amount requested.
        vm.mockCall(
            address(usdcBase),
            abi.encodeCall(IERC20Like.balanceOf, address(almProxy)),
            abi.encode(10_000e6 - 1) // Return less than amount
        );

        vm.expectRevert("AaveFacet/borrow-amount-too-low");
        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18);

        vm.clearMockedCalls();

        vm.prank(relayer);
        foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18);
    }

    function test_borrowAave_usdc() external {
        bytes32 borrowKey = makeAddressKey(foreignController.LIMIT_AAVE_BORROW(), ATOKEN_USDC);

        assertEq(_getDebtBalance(address(usdcBase)),            0); // Current debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         0);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     15_000e6);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveBorrow(ATOKEN_USDC, 10_000e6, 78e18);

        vm.prank(relayer);
        assertEq(foreignController.borrowAave(ATOKEN_USDC, 10_000e6, 1e18), 10_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(_getDebtBalance(address(usdcBase)),            10_000e6); // New debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         10_000e6);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     15_000e6 - 10_000e6);
    }

}

contract ForeignController_AaveV3_Repay_Tests is AaveV3_TestBase {

    function setUp() public override {
        super.setUp();

        // Deposit and borrow USDC to be able to repay.

        deal(Base.USDC, address(almProxy), 1_000_000e6);

        vm.startPrank(relayer);

        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
        foreignController.borrowAave(ATOKEN_USDC, 15_000e6, 1e18);

        vm.stopPrank();
    }

    function test_repayAave_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.repayAave(ATOKEN_USDC, 1_000e6);
    }

    function test_repayAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        foreignController.repayAave(ATOKEN_USDC, 1_000e6);
    }

    function test_repayAave_zeroMaxAmount() external {
        vm.startPrank(Base.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_REPAY(), ATOKEN_USDC),
            0,
            0
        );
        vm.stopPrank();

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        foreignController.repayAave(ATOKEN_USDC, 1_000e6);
    }

    function test_repayAave_usdc_amountTooHighBoundary() external {
        vm.mockCall(
            POOL,
            abi.encodeCall(IAavePoolLike.repay,(address(usdcBase), 5_000e6, 2, address(almProxy))),
            abi.encode(5_000e6 + 1) // Return more than amount, causing revert
        );

        vm.expectRevert("AaveFacet/repay-amount-too-high");
        vm.prank(relayer);
        foreignController.repayAave(ATOKEN_USDC, 5_000e6);

        vm.clearMockedCalls();

        vm.prank(relayer);
        foreignController.repayAave(ATOKEN_USDC, 5_000e6);
    }

    function test_repayAave_usdcRateLimitedBoundary() external {
        vm.warp(block.timestamp + 1 hours); // Warp to get debt accrued.

        // Deal extra USDC for repay.
        deal(Base.USDC, address(almProxy), 15_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        foreignController.repayAave(ATOKEN_USDC, 15_000e6 + 1);

        vm.prank(relayer);
        foreignController.repayAave(ATOKEN_USDC, 15_000e6);
    }

    function test_repayAave_usdc_partialRepay() external {
        bytes32 borrowKey = makeAddressKey(foreignController.LIMIT_AAVE_BORROW(), ATOKEN_USDC);
        bytes32 repayKey  = makeAddressKey(foreignController.LIMIT_AAVE_REPAY(),  ATOKEN_USDC);

        assertEq(_getDebtBalance(address(usdcBase)),            15_000e6); // Current debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         15_000e6);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     0);
        assertEq(rateLimits.getCurrentRateLimit(repayKey),      15_000e6);

        vm.record();

        // Partial repay.
        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveRepay(ATOKEN_USDC, 5_000e6);

        vm.prank(relayer);
        assertEq(foreignController.repayAave(ATOKEN_USDC, 5_000e6), 5_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(_getDebtBalance(address(usdcBase)),            15_000e6 - 5_000e6); // New debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         15_000e6 - 5_000e6);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     5_000e6);
        assertEq(rateLimits.getCurrentRateLimit(repayKey),      15_000e6 - 5_000e6);
    }

    function test_repayAave_usdc_fullRepay() external {
        bytes32 borrowKey = makeAddressKey(foreignController.LIMIT_AAVE_BORROW(), ATOKEN_USDC);
        bytes32 repayKey  = makeAddressKey(foreignController.LIMIT_AAVE_REPAY(),  ATOKEN_USDC);

        assertEq(_getDebtBalance(address(usdcBase)),            15_000e6); // Current debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         15_000e6);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     0);
        assertEq(rateLimits.getCurrentRateLimit(repayKey),      15_000e6);
        assertEq(usdcBase.allowance(address(almProxy), POOL),   0);

        vm.record();

        // Full repay.
        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveRepay(ATOKEN_USDC, 15_000e6);

        vm.prank(relayer);
        assertEq(foreignController.repayAave(ATOKEN_USDC, type(uint256).max), 15_000e6); // Max amount

        _assertReentrancyGuardWrittenToTwice();

        assertEq(_getDebtBalance(address(usdcBase)),            0); // New debt
        assertEq(usdcBase.balanceOf(address(almProxy)),         0);
        assertEq(rateLimits.getCurrentRateLimit(borrowKey),     15_000e6);
        assertEq(rateLimits.getCurrentRateLimit(repayKey),      0);
        assertEq(usdcBase.allowance(address(almProxy), POOL),   type(uint256).max - 15_000e6); // Dangling allowance
    }

}

contract ForeignController_AaveV3_Deposit_Tests is AaveV3_TestBase {

    function test_depositAave_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_depositAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_depositAave_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        foreignController.depositAave(makeAddr("fake-token"), 1e18);
    }

    function test_depositAave_zeroMaxSlippage() external {
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveMaxSlippage(ATOKEN_USDC, 0);

        vm.expectRevert("AaveFacet/max-slippage-not-set");
        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
    }

    function test_depositAave_usdcRateLimitedBoundary() external {
        deal(Base.USDC, address(almProxy), 1_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6 + 1);

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
    }

    function test_depositAave_usdcSlippageBoundary() external {
        deal(Base.USDC, address(almProxy), 1_000_000e6);

        // Positive slippage because of no rounding error
        // 1e6 * 1_000_000e6 / 1e18 = 1
        // (1e6 - 1) * 1_000_000e6 / 1e18 = 0
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveMaxSlippage(ATOKEN_USDC, 1e18 + 1e6);

        vm.expectRevert("AaveFacet/slippage-too-high");
        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setAaveMaxSlippage(ATOKEN_USDC, 1e18 + 1e6 - 1);

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
    }

    function test_depositAave_usdc() external {
        deal(Base.USDC, address(almProxy), 1_000_000e6);

        assertEq(usdcBase.allowance(address(almProxy), POOL), 0);

        assertEq(AUSDC.balanceOf(address(almProxy)),    0);
        assertEq(usdcBase.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance);

        vm.record();

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveDeposit(ATOKEN_USDC, 1_000_000e6);

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usdcBase.allowance(address(almProxy), POOL), 0);

        assertEq(AUSDC.balanceOf(address(almProxy)),    1_000_000e6);
        assertEq(usdcBase.balanceOf(address(almProxy)), 0);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 1_000_000e6);
    }

}

contract ForeignController_AaveV3_Withdraw_Tests is AaveV3_TestBase {

    function test_withdrawAave_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_withdrawAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER_ROLE
        ));
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_withdrawAave_zeroMaxAmount() external {
        // Longer setup because rate limit revert is at the end of the function
        vm.startPrank(Base.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(
            makeAddressKey(foreignController.LIMIT_AAVE_WITHDRAW(), ATOKEN_USDC),
            0,
            0
        );
        vm.stopPrank();

        deal(Base.USDC, address(almProxy), 1_000_000e6);

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e6);
    }

    function test_withdrawAave_usdcRateLimitedBoundary() external {
        deal(Base.USDC, address(almProxy), 2_000_000e6);

        // Warp to get past rate limit
        vm.startPrank(relayer);

        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        skip(1 days);

        foreignController.depositAave(ATOKEN_USDC, 100_000e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e6 + 1);

        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e6);

        vm.stopPrank();
    }

    function test_withdrawAave_usdc() external {
        bytes32 depositKey  = makeAddressKey(foreignController.LIMIT_AAVE_DEPOSIT(),  ATOKEN_USDC);
        bytes32 withdrawKey = makeAddressKey(foreignController.LIMIT_AAVE_WITHDRAW(), ATOKEN_USDC);

        // NOTE: Using lower amount to not hit rate limit
        deal(Base.USDC, address(almProxy), 500_000e6);

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveDeposit({ aToken: ATOKEN_USDC, amount: 500_000e6 });

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 500_000e6);

        skip(1 hours);

        uint256 aTokenBalance = AUSDC.balanceOf(address(almProxy));

        assertEq(aTokenBalance, 500_009.705892e6);  // Earn some interest

        assertEq(AUSDC.balanceOf(address(almProxy)),    aTokenBalance);
        assertEq(usdcBase.balanceOf(address(almProxy)), 0);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 500_000e6);

        uint256 startingDepositRateLimit = rateLimits.getCurrentRateLimit(depositKey);

        assertEq(startingDepositRateLimit, 500_000e6 + uint256(1_000_000e6) / 1 days * 1 hours);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  startingDepositRateLimit);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 1_000_000e6);

        vm.record();

        // Partial withdraw
        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveWithdraw(ATOKEN_USDC, 400_000e6);

        vm.prank(relayer);
        assertEq(foreignController.withdrawAave(ATOKEN_USDC, 400_000e6), 400_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(AUSDC.balanceOf(address(almProxy)),    aTokenBalance - (400_000e6 - 1));  // Rounding
        assertEq(usdcBase.balanceOf(address(almProxy)), 400_000e6);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 100_000e6);  // 500k - 400k

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  startingDepositRateLimit + 400_000e6);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 600_000e6);

        // Withdraw all
        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveWithdraw({
            aToken          : ATOKEN_USDC,
            amountWithdrawn : aTokenBalance - 400_000e6 + 1  // Rounding
        });

        vm.prank(relayer);
        assertEq(foreignController.withdrawAave(ATOKEN_USDC, type(uint256).max), aTokenBalance - 400_000e6 + 1);  // Rounding

        assertEq(AUSDC.balanceOf(address(almProxy)),    0);
        assertEq(usdcBase.balanceOf(address(almProxy)), aTokenBalance + 1);  // Rounding
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 500_000e6 - aTokenBalance - 1);  // Rounding

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  1_000_000e6);  // Maxes out at 1m
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), 1_000_000e6 - aTokenBalance - 1);  // Rounding

        // Interest accrued was withdrawn, reducing cash balance
        assertLt(usdcBase.balanceOf(ATOKEN_USDC), startingAUSDCBalance);
    }

    function test_withdrawAave_usdc_unlimitedRateLimit() external {
        bytes32 depositKey  = makeAddressKey(foreignController.LIMIT_AAVE_DEPOSIT(),  ATOKEN_USDC);
        bytes32 withdrawKey = makeAddressKey(foreignController.LIMIT_AAVE_WITHDRAW(), ATOKEN_USDC);

        vm.prank(Base.SPARK_EXECUTOR);
        rateLimits.setUnlimitedRateLimitData(withdrawKey);

        deal(Base.USDC, address(almProxy), 1_000_000e6);

        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveDeposit({ aToken: ATOKEN_USDC, amount: 1_000_000e6 });

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        skip(1 hours);

        uint256 aTokenBalance = AUSDC.balanceOf(address(almProxy));

        assertEq(aTokenBalance, 1_000_015.893506e6);  // Earn some interest

        uint256 startingDepositRateLimit = rateLimits.getCurrentRateLimit(depositKey);

        assertEq(startingDepositRateLimit, uint256(1_000_000e6) / 1 days * 1 hours);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  startingDepositRateLimit);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);

        assertEq(AUSDC.balanceOf(address(almProxy)),    aTokenBalance);
        assertEq(usdcBase.balanceOf(address(almProxy)), 0);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 1_000_000e6);

        // Full withdraw
        vm.expectEmit(address(foreignController));
        emit IAaveFacet.AaveWithdraw({ aToken: ATOKEN_USDC, amountWithdrawn: aTokenBalance });

        vm.prank(relayer);
        assertEq(foreignController.withdrawAave(ATOKEN_USDC, type(uint256).max), aTokenBalance);

        assertEq(rateLimits.getCurrentRateLimit(depositKey),  1_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey), type(uint256).max);  // No change

        assertEq(AUSDC.balanceOf(address(almProxy)),    0);
        assertEq(usdcBase.balanceOf(address(almProxy)), aTokenBalance);
        assertEq(usdcBase.balanceOf(ATOKEN_USDC),       startingAUSDCBalance + 1_000_000e6 - aTokenBalance);
    }

}
