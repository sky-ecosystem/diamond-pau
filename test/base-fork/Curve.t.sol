// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { MockERC20Decimals } from "../mocks/Mocks.sol";

import { makeAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { ForkTestBase, ERC20Mock } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

}

interface ICurvePoolLike {

    function add_liquidity(uint256[] calldata amounts, uint256 minMintAmount, address receiver)
        external;

    function balances(uint256 index) external view returns (uint256);

    function calc_token_amount(uint256[] memory amounts, bool is_deposit) external view returns (uint256);

    function calc_withdraw_one_coin(uint256 amount, int128 index) external view returns (uint256);

    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);

    function get_virtual_price() external view returns (uint256);


    function stored_rates() external view returns (uint256[] memory);

}

abstract contract Curve_TestBase is ForkTestBase {

    // TODO: replace with real target pool once available
    address internal constant CURVE_POOL = 0xa9D6867C347B8b5f395B8421FB31710B8Fb21a16; // USDC/cgUSD
    address internal constant CGUSD      = 0xCa72827a3D211CfD8F6b00Ac98824872b72CAb49;

    IERC20Like internal curveLp = IERC20Like(CURVE_POOL);
    IERC20Like internal cgUSD   = IERC20Like(CGUSD);

    ICurvePoolLike internal curvePool = ICurvePoolLike(CURVE_POOL);

    bytes32 internal curveDepositKey;
    bytes32 internal curveSwapKey;
    bytes32 internal curveWithdrawKey;

    uint256 internal maxSlippage;

    function setUp() public virtual override  {
        super.setUp();

        // There is something weird with the CGUSD token that causes deal to under/overflow.
        // Make a mock Decimal 6 token and replace it for these tests
        uint256   curveCGUSDBalance = cgUSD.balanceOf(CURVE_POOL);
        ERC20Mock mockCgUSD         = ERC20Mock(address(new MockERC20Decimals("cgUSD", "cgUSD", 6)));
        vm.etch(CGUSD, address(mockCgUSD).code);

        // Preserve the balance of the CGUSD token in the pool
        deal(address(cgUSD), CURVE_POOL, curveCGUSDBalance);

        address liquidityProvider = makeAddr("liquidityProvider");

        if (curveCGUSDBalance < 100_000_000e6 || usdcBase.balanceOf(CURVE_POOL) < 100_000_000e6) {
            // boost liquidity to help later tests
            uint256 amount = 100_000_000e6;
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amount;
            amounts[1] = amount;

            deal(address(usdcBase), liquidityProvider, amount);
            deal(address(cgUSD),    liquidityProvider, amount);

            vm.startPrank(liquidityProvider);

            usdcBase.approve(CURVE_POOL, amount);
            cgUSD.approve(CURVE_POOL,    amount);
            ICurvePoolLike(CURVE_POOL).add_liquidity(amounts, 1e18, liquidityProvider);

            vm.stopPrank();
        }

        curveDepositKey  = makeAddressKey(foreignController.LIMIT_CURVE_DEPOSIT(),  CURVE_POOL);
        curveSwapKey     = makeAddressKey(foreignController.LIMIT_CURVE_SWAP(),     CURVE_POOL);
        curveWithdrawKey = makeAddressKey(foreignController.LIMIT_CURVE_WITHDRAW(), CURVE_POOL);

        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveDepositKey,  2_000_000e18, uint256(2_000_000e18) / 1 days);
        rateLimits.setRateLimitData(curveSwapKey,     1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(curveWithdrawKey, 3_000_000e18, uint256(3_000_000e18) / 1 days);
        vm.stopPrank();

        // Set a higher slippage to allow for successes
        maxSlippage = 0.98e18;
        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, maxSlippage);

        _labelAddresses();
    }

    function _labelAddresses() internal {
        vm.label(address(usdcBase), "UsdcBase");
        vm.label(CGUSD,             "CgUSD");
        vm.label(CURVE_POOL,        "CurvePool");
    }

    function _addLiquidity(uint256 usdcAmount, uint256 cgUSDAmount)
        internal returns (uint256 lpTokensReceived)
    {
        deal(address(usdcBase), almProxy, usdcAmount);
        deal(address(cgUSD),    almProxy, cgUSDAmount);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = cgUSDAmount;

        uint256 minLpAmount = (usdcAmount + cgUSDAmount) * 1e12 * 98 / 100;

        vm.prank(RELAYER);
        lpTokensReceived = foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
        return lpTokensReceived;
    }

    function _addLiquidity() internal returns (uint256 lpTokensReceived) {
        return _addLiquidity(1_000_000e6, 1_000_000e6);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 36918285;  // Oct 16, 2025 02:45:17 PM +UTC
    }

    function _calcMinWithdrawAmounts(uint256 lpBurnAmount) internal view returns (uint256[] memory) {
        uint256[] memory rates = curvePool.stored_rates();
        uint256[] memory minWithdrawAmounts = new uint256[](2);
        uint256 totalSupply = curveLp.totalSupply();
        uint256 virtualPrice = curvePool.get_virtual_price();

        // Calculate the minimum required total value based on slippage
        // This matches CurveFacet: valueMinWithdrawn >= lpBurnAmount * virtualPrice * maxSlippage / 1e36
        // After the /1e18 normalization in CurveFacet, this gives us the min value in 18 decimals
        uint256 minRequiredValue = lpBurnAmount * virtualPrice * maxSlippage / 1e36; // in 18 decimal precision

        // Calculate expected withdrawal amounts proportionally
        uint256[] memory expectedAmounts = new uint256[](2);
        uint256 totalExpectedValue = 0;

        for (uint256 i = 0; i < 2; i++) {
            expectedAmounts[i] = curvePool.balances(i) * lpBurnAmount / totalSupply;
            totalExpectedValue += expectedAmounts[i] * rates[i];
        }
        totalExpectedValue /= 1e18; // Normalize to 18 decimals to match CurveFacet

        // Distribute the minimum required value proportionally across tokens
        // Add 1 to each amount to compensate for rounding errors and ensure we're at/above the boundary
        for (uint256 i = 0; i < 2; i++) {
            minWithdrawAmounts[i] = expectedAmounts[i] * minRequiredValue / totalExpectedValue + 1;
        }

        return minWithdrawAmounts;
    }

}

contract ForeignController_Curve_AddLiquidity_Tests is Curve_TestBase {

    function test_addLiquidityCurve_notRelayer() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));

        vm.prank(unauthorized);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve_slippageNotSet() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0);

        vm.expectRevert("CurveFacet/max-slippage-not-set");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve_invalidDepositAmountsLength() external {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;
        amounts[2] = 1_000_000e6;
        amounts[3] = 0;
        amounts[4] = 0;

        uint256 minLpAmount = 0;

        vm.expectRevert("CurveFacet/invalid-deposit-amounts");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        uint256[] memory amounts2 = new uint256[](1);
        amounts[0] = 1_000_000e6;

        vm.expectRevert("CurveFacet/invalid-deposit-amounts");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts2, minLpAmount);
    }

    function test_addLiquidityCurve_underAllowableSlippageBoundary() external {
        deal(address(usdcBase), almProxy, 1_000_000e6);
        deal(address(cgUSD),    almProxy, 1_000_000e6);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 boundaryAmount = 2_000_000e18 * 0.98e18 / curvePool.get_virtual_price();

        assertApproxEqAbs(boundaryAmount, 1_950_000e18, 50_000e18);  // Sanity check on precision

        uint256 minLpAmount = boundaryAmount - 1;

        vm.expectRevert("CurveFacet/min-amount-not-met");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        minLpAmount = boundaryAmount;

        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve_zeroMaxAmount() external {
        bytes32 curveDeposit = makeAddressKey(foreignController.LIMIT_CURVE_DEPOSIT(), CURVE_POOL);

        vm.prank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveDeposit, 0, 0);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve_rateLimitBoundaryAsset0() external {
        deal(address(usdcBase), almProxy, 1_000_000e6);
        deal(address(cgUSD),    almProxy, 1_000_000e6);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        amounts[0] = 1_000_000e6 + 1;

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        amounts[0] = 1_000_000e6;

        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve_rateLimitBoundaryAsset1() external {
        deal(address(usdcBase), almProxy, 1_000_000e6);
        deal(address(cgUSD),    almProxy, 1_000_000e6);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        amounts[1] = 1_000_000e6 + 1;

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        amounts[1] = 1_000_000e6;

        vm.prank(RELAYER);
        foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

    function test_addLiquidityCurve() external {
        deal(address(usdcBase), almProxy, 1_000_000e6);
        deal(address(cgUSD),    almProxy, 1_000_000e6);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        uint256 startingCgUSDBalance = cgUSD.balanceOf(CURVE_POOL);
        uint256 startingUsdcBalance = usdcBase.balanceOf(CURVE_POOL);
        uint256 startingTotalSupply = curveLp.totalSupply();

        assertEq(usdcBase.allowance(almProxy, CURVE_POOL), 0);
        assertEq(cgUSD.allowance(almProxy,    CURVE_POOL), 0);

        assertEq(usdcBase.balanceOf(almProxy),   1_000_000e6);
        assertEq(usdcBase.balanceOf(CURVE_POOL), startingUsdcBalance);

        assertEq(cgUSD.balanceOf(almProxy),   1_000_000e6);
        assertEq(cgUSD.balanceOf(CURVE_POOL), startingCgUSDBalance);

        assertEq(curveLp.balanceOf(almProxy), 0);
        assertEq(curveLp.totalSupply(),       startingTotalSupply);

        assertEq(rateLimits.getCurrentRateLimit(curveDepositKey), 2_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(curveSwapKey),    1_000_000e18);

        vm.prank(RELAYER);
        uint256 lpTokensReceived = foreignController.addLiquidityCurve(
            CURVE_POOL,
            amounts,
            minLpAmount
        );

        assertEq(lpTokensReceived, minLpAmount);

        assertEq(usdcBase.allowance(almProxy, CURVE_POOL), 0);
        assertEq(cgUSD.allowance(almProxy,    CURVE_POOL), 0);

        assertEq(usdcBase.balanceOf(almProxy),   0);
        assertEq(usdcBase.balanceOf(CURVE_POOL), startingUsdcBalance + 1_000_000e6);

        assertEq(cgUSD.balanceOf(almProxy),   0);
        assertEq(cgUSD.balanceOf(CURVE_POOL), startingCgUSDBalance + 1_000_000e6);

        assertEq(curveLp.balanceOf(almProxy), lpTokensReceived);
        assertEq(curveLp.totalSupply(),       startingTotalSupply + lpTokensReceived);

        // Should have used the full deposit rate limit
        assertEq(rateLimits.getCurrentRateLimit(curveDepositKey), 0);
        // There was an imbalance so the swap key should have reduced
        assertLt(rateLimits.getCurrentRateLimit(curveSwapKey),    1_000_000e18);
    }

    function test_addLiquidityCurve_swapRateLimit() external {
        // Set a higher slippage to allow for successes
        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0.1e18);

        deal(address(usdcBase), almProxy, 1_000_000e6);

        // Step 1: Add liquidity, check how much the rate limit was reduced

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 0;

        uint256 minLpAmount = 100_000e18;

        uint256 startingRateLimit = rateLimits.getCurrentRateLimit(curveSwapKey);

        uint256 expectedLpTokens = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);

        vm.prank(RELAYER);
        uint256 lpTokens = foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        assertEq(lpTokens, expectedLpTokens, "expected lp tokens not received");

        uint256 derivedSwapAmount = startingRateLimit - rateLimits.getCurrentRateLimit(curveSwapKey);

        // Step 2: Calculate expected withdrawal amounts for each token

        // Get pool state
        uint256[] memory rates = ICurvePoolLike(CURVE_POOL).stored_rates();
        uint256 totalSupply    = curveLp.totalSupply();

        // Calculate expected withdrawal amounts for each token
        uint256[] memory expectedWithdrawnAmounts = new uint256[](2);
        expectedWithdrawnAmounts[0] = ((ICurvePoolLike(CURVE_POOL).balances(0) * lpTokens) / totalSupply);
        expectedWithdrawnAmounts[1] = ((ICurvePoolLike(CURVE_POOL).balances(1) * lpTokens) / totalSupply);

        // Step 3: Calculate the average difference between the assets deposited and withdrawn, into an average swap amount
        //         and compare against the derived swap amount

        uint256 totalSwapped;
        for (uint256 i; i < expectedWithdrawnAmounts.length; i++) {
            totalSwapped += _absSubtraction(expectedWithdrawnAmounts[i] * rates[i], amounts[i] * rates[i]) / 1e18;
        }
        totalSwapped /= 2;

        // Difference is accurate to within 1 unit of USDC
        assertApproxEqAbs(derivedSwapAmount, totalSwapped, 0.000001e18);
    }

    function testFuzz_addLiquidityCurve_swapRateLimit(uint256 usdcAmount, uint256 cgUSDAmount) external {
        // Set slippage to be zero and unlimited rate limits for purposes of this test
        // Not using actual unlimited rate limit because need to get swap amount to be reduced.
        vm.startPrank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 1);
        rateLimits.setUnlimitedRateLimitData(curveDepositKey);
        rateLimits.setUnlimitedRateLimitData(curveWithdrawKey);
        rateLimits.setRateLimitData(curveSwapKey, type(uint256).max - 1, type(uint256).max - 1);
        vm.stopPrank();

        usdcAmount  = _bound(usdcAmount , 1_000_000e6, 10_000_000_000e6);
        cgUSDAmount = _bound(cgUSDAmount, 1_000_000e6, 10_000_000_000e6);

        deal(address(usdcBase), almProxy, usdcAmount);
        deal(address(cgUSD),    almProxy, cgUSDAmount);

        // Step 1: Add liquidity with fuzzed inputs, check how much the rate limit was reduced

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = cgUSDAmount;

        uint256 startingRateLimit = rateLimits.getCurrentRateLimit(curveSwapKey);

        vm.prank(RELAYER);
        uint256 lpTokens = foreignController.addLiquidityCurve(CURVE_POOL, amounts, 1e18);

        uint256 derivedSwapAmount = startingRateLimit - rateLimits.getCurrentRateLimit(curveSwapKey);

        // Step 2: Withdraw full balance of LP tokens, withdrawing proportional amounts from the pool

        uint256[] memory minWithdrawnAmounts = new uint256[](2);
        minWithdrawnAmounts[0] = 1e6;
        minWithdrawnAmounts[1] = 1e6;

        vm.prank(RELAYER);
        uint256[] memory withdrawnAmounts = foreignController.removeLiquidityCurve(CURVE_POOL, lpTokens, minWithdrawnAmounts);

        // Step 3: Calculate the average difference between the assets deposited and withdrawn, into an average swap amount
        //         and compare against the derived swap amount

        uint256[] memory rates = ICurvePoolLike(CURVE_POOL).stored_rates();

        uint256 totalSwapped;
        for (uint256 i; i < withdrawnAmounts.length; i++) {
            totalSwapped += _absSubtraction(withdrawnAmounts[i] * rates[i], amounts[i] * rates[i]) / 1e18;
        }
        totalSwapped /= 2;

        // Difference is accurate to within 1 unit of USDC
        assertApproxEqAbs(derivedSwapAmount, totalSwapped, 0.000001e18);
    }

}

contract ForeignController_Curve_RemoveLiquidity_Tests is Curve_TestBase {

    function test_removeLiquidityCurve_notRelayer() external {
        uint256[] memory minWithdrawAmounts = new uint256[](2);
        minWithdrawAmounts[0] = 1_000_000e6;
        minWithdrawAmounts[1] = 1_000_000e6;

        uint256 lpReturn = 1_980_000e18;

        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));

        vm.prank(unauthorized);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpReturn, minWithdrawAmounts);
    }

    function test_removeLiquidityCurve_slippageNotSet() external {
        uint256[] memory minWithdrawAmounts = new uint256[](2);
        minWithdrawAmounts[0] = 1_000_000e6;
        minWithdrawAmounts[1] = 1_000_000e6;

        uint256 lpReturn = 1_980_000e18;

        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0);

        vm.expectRevert("CurveFacet/max-slippage-not-set");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpReturn, minWithdrawAmounts);
    }

    function test_removeLiquidityCurve_invalidDepositAmountsLength() external {
        uint256[] memory minWithdrawAmounts = new uint256[](3);
        minWithdrawAmounts[0] = 1_000_000e6;
        minWithdrawAmounts[1] = 1_000_000e6;
        minWithdrawAmounts[2] = 1_000_000e6;

        uint256 lpReturn = 1_980_000e18;

        vm.expectRevert("CurveFacet/invalid-min-withdraw-amounts");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpReturn, minWithdrawAmounts);

        uint256[] memory minWithdrawAmounts2 = new uint256[](1);
        minWithdrawAmounts[0] = 1_000_000e6;

        vm.expectRevert("CurveFacet/invalid-min-withdraw-amounts");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpReturn, minWithdrawAmounts2);
    }

    function test_removeLiquidityCurve_underAllowableSlippageBoundary() external {
        uint256 lpTokensReceived = _addLiquidity(1_000_000e6, 1_000_000e6);

        uint256 minTotalReturned = lpTokensReceived * curvePool.get_virtual_price() * 98/100 / 1e18;

        assertApproxEqAbs(minTotalReturned, 1_960_000e18, 50_000e18);  // Sanity check on precision

        // Get boundary amounts, then subtract to go below boundary (should fail)
        uint256[] memory minWithdrawAmounts = _calcMinWithdrawAmounts(lpTokensReceived);
        minWithdrawAmounts[0] -= 100;

        vm.expectRevert("CurveFacet/min-amount-not-met");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);

        // Add back to get to the boundary (should succeed)
        minWithdrawAmounts[0] += 100;

        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);
    }

    function test_removeLiquidityCurve_zeroMaxAmount() external {
        bytes32 curveWithdraw = makeAddressKey(foreignController.LIMIT_CURVE_WITHDRAW(), CURVE_POOL);

        vm.prank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveWithdraw, 0, 0);

        uint256 lpTokensReceived = _addLiquidity(1_000_000e6, 1_000_000e6);

        uint256[] memory minWithdrawAmounts = _calcMinWithdrawAmounts(lpTokensReceived);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);
    }

    function test_removeLiquidityCurve_rateLimitBoundary() external {
        uint256 lpTokensReceived = _addLiquidity(1_000_000e6, 1_000_000e6);

        uint256[] memory minWithdrawAmounts = _calcMinWithdrawAmounts(lpTokensReceived);

        uint256 id = vm.snapshotState();

        // Use a success call to see how many tokens are returned from burning all LP tokens
        vm.prank(RELAYER);
        uint256[] memory withdrawnAmounts = foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);

        uint256 totalWithdrawn = (withdrawnAmounts[0] + withdrawnAmounts[1]) * 1e12;

        vm.revertToState(id);

        bytes32 curveWithdraw = makeAddressKey(foreignController.LIMIT_CURVE_WITHDRAW(), CURVE_POOL);

        // Set to below boundary
        vm.prank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveWithdraw, totalWithdrawn - 1, totalWithdrawn / 1 days);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);

        // Set to boundary
        vm.prank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveWithdraw, totalWithdrawn, totalWithdrawn / 1 days);

        vm.prank(RELAYER);
        foreignController.removeLiquidityCurve(CURVE_POOL, lpTokensReceived, minWithdrawAmounts);
    }

    function test_removeLiquidityCurve() external {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;
        uint256 lpTokensEstimated = ICurvePoolLike(CURVE_POOL).calc_token_amount(amounts, true);
        uint256 lpTokensReceived  = _addLiquidity(amounts[0], amounts[1]);

        uint256 startingCgUSDBalance = cgUSD.balanceOf(CURVE_POOL);
        uint256 startingUsdcBalance  = usdcBase.balanceOf(CURVE_POOL);
        uint256 startingTotalSupply  = curveLp.totalSupply();

        assertEq(lpTokensEstimated, lpTokensReceived, "Estimated LP amount does not match received LP tokens");

        assertEq(curveLp.allowance(almProxy, CURVE_POOL), 0);

        assertEq(cgUSD.balanceOf(almProxy),    0);
        assertEq(usdcBase.balanceOf(almProxy), 0);

        assertEq(curveLp.balanceOf(almProxy), lpTokensReceived);
        assertEq(curveLp.totalSupply(),       startingTotalSupply);

        assertEq(rateLimits.getCurrentRateLimit(curveWithdrawKey), 3_000_000e18);

        uint256[] memory minWithdrawAmounts = _calcMinWithdrawAmounts(lpTokensReceived);

        uint256[] memory rates = ICurvePoolLike(CURVE_POOL).stored_rates();

        vm.prank(RELAYER);
        uint256[] memory assetsReceived = foreignController.removeLiquidityCurve(
            CURVE_POOL,
            lpTokensReceived,
            minWithdrawAmounts
        );

        assertGe(assetsReceived[0], minWithdrawAmounts[0], "wrong index 0 amount received");
        assertGe(assetsReceived[1], minWithdrawAmounts[1], "wrong index 1 amount received");

        uint256 sumAssetsReceived = assetsReceived[0] + assetsReceived[1];

        assertGe(sumAssetsReceived, minWithdrawAmounts[0] + minWithdrawAmounts[1], "sum of assets received is less than min withdraw amounts");

        assertEq(curveLp.allowance(almProxy, CURVE_POOL), 0, "allowance is not 0");

        assertEq(usdcBase.balanceOf(almProxy), assetsReceived[0], "wrong ALM proxy USDC balance");

        assertEq(cgUSD.balanceOf(almProxy), assetsReceived[1], "wrong ALM proxy cgUSD balance");

        assertEq(curveLp.balanceOf(almProxy), 0, "ALM proxy LP balance is not 0");
        assertEq(curveLp.totalSupply(),       startingTotalSupply - lpTokensReceived, "LP total supply is not correct");

        uint256 calcValueWithdrawn;
        for (uint256 i; i < rates.length; i++) {
            calcValueWithdrawn += rates[i] * assetsReceived[i];
        }
        calcValueWithdrawn /= 1e18;
        assertEq(rateLimits.getCurrentRateLimit(curveWithdrawKey) + calcValueWithdrawn, 3_000_000e18, "rate limit is not correct");
    }

}

contract ForeignController_Curve_Swap_Tests is Curve_TestBase {

    function test_swapCurve_notRelayer() external {
        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));

        vm.prank(unauthorized);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_sameIndex() external {
        vm.expectRevert("CurveFacet/invalid-indices");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 1, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_firstIndexTooHighBoundary() external {
        _addLiquidity();
        skip(1 days);  // Recharge swap rate limit from deposit

        deal(address(cgUSD), almProxy, 1_000_000e6);

        vm.expectRevert("CurveFacet/index-too-high");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 4, 0, 1_000_000e6, 980_000e6);

        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_secondIndexTooHighBoundary() external {
        _addLiquidity();
        skip(1 days);  // Recharge swap rate limit from deposit

        deal(address(usdcBase), almProxy, 1_000_000e6);

        vm.expectRevert("CurveFacet/index-too-high");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 0, 4, 1_000_000e6, 980_000e6);

        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 0, 1, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_slippageNotSet() external {
        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0);

        vm.expectRevert("CurveFacet/max-slippage-not-set");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_underAllowableSlippageBoundaryAsset0To1() external {
        _addLiquidity();
        skip(1 days);  // Recharge swap rate limit from deposit

        deal(address(usdcBase), almProxy, 1_000_000e6);

        vm.expectRevert("CurveFacet/min-amount-not-met");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 0, 1, 1_000_000e6, 980_000e6 - 1);

        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 0, 1, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_underAllowableSlippageBoundaryAsset1To0() external {
        _addLiquidity();
        skip(1 days);  // Recharge swap rate limit from deposit

        deal(address(cgUSD), almProxy, 1_000_000e6);

        vm.expectRevert("CurveFacet/min-amount-not-met");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6 - 1);

        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_zeroMaxAmount() external {
        bytes32 curveSwap = makeAddressKey(foreignController.LIMIT_CURVE_SWAP(), CURVE_POOL);

        vm.prank(SPARK_EXECUTOR);
        rateLimits.setRateLimitData(curveSwap, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 980_000e6);
    }

    function test_swapCurve_rateLimitBoundary() external {
        _addLiquidity();
        skip(1 days);  // Recharge swap rate limit from deposit

        deal(address(cgUSD), almProxy, 1_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6 + 1, 998_000e6);

        vm.prank(RELAYER);
        foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 998_000e6);
    }

    function test_swapCurve() external {
        _addLiquidity(1_000_000e6, 1_000_000e6);
        skip(1 days);  // Recharge swap rate limit from deposit

        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0.999e18);  // 0.1%

        uint256 startingCgUSDBalance = cgUSD.balanceOf(CURVE_POOL);
        uint256 startingUsdcBalance  = usdcBase.balanceOf(CURVE_POOL);

        deal(address(cgUSD), almProxy, 1_000_000e6);

        assertEq(cgUSD.balanceOf(almProxy),   1_000_000e6);
        assertEq(cgUSD.balanceOf(CURVE_POOL), startingCgUSDBalance);

        assertEq(usdcBase.balanceOf(almProxy),   0);
        assertEq(usdcBase.balanceOf(CURVE_POOL), startingUsdcBalance);

        assertEq(rateLimits.getCurrentRateLimit(curveSwapKey), 1_000_000e18);

        assertEq(usdcBase.allowance(almProxy, CURVE_POOL), 0);
        assertEq(cgUSD.allowance(almProxy,    CURVE_POOL), 0);

        // Calculate expected swap output dynamically
        uint256 expectedAmountOut = curvePool.get_dy(1, 0, 1_000_000e6);

        // Calculate minAmountOut to pass CurveFacet slippage check
        // CurveFacet requires: minAmountOut >= amountIn * rateIn * maxSlippage / rateOut / 1e18
        uint256[] memory rates = curvePool.stored_rates();
        uint256 minAmountOut = 1_000_000e6 * rates[1] * 0.999e18 / rates[0] / 1e18;

        vm.prank(RELAYER);
        uint256 amountOut = foreignController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, minAmountOut);

        assertEq(amountOut, expectedAmountOut);

        assertEq(usdcBase.allowance(almProxy, CURVE_POOL), 0);
        assertEq(cgUSD.allowance(almProxy,    CURVE_POOL), 0);

        assertEq(cgUSD.balanceOf(almProxy),   0);
        assertEq(cgUSD.balanceOf(CURVE_POOL), startingCgUSDBalance + 1_000_000e6);

        assertEq(usdcBase.balanceOf(almProxy),   amountOut);
        assertEq(usdcBase.balanceOf(CURVE_POOL), startingUsdcBalance - amountOut);

        assertEq(rateLimits.getCurrentRateLimit(curveSwapKey), 0);
    }

}

contract ForeignController_Curve_GetVirtualPrice_StressTests is Curve_TestBase {

    function test_getVirtualPrice_stressTest() external {
        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.setUnlimitedRateLimitData(curveDepositKey);
        rateLimits.setUnlimitedRateLimitData(curveSwapKey);
        rateLimits.setUnlimitedRateLimitData(curveWithdrawKey);
        vm.stopPrank();

        _addLiquidity(100_000_000e6, 100_000_000e6);

        uint256 virtualPrice1 = curvePool.get_virtual_price();

        // Verify initial virtual price is reasonable (pool may have slight imbalance from setup)
        assertApproxEqRel(virtualPrice1, 1.020385339110137837e18, 0.01e18);  // Within 1%

        deal(address(usdcBase), almProxy, 100_000_000e6);

        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 1);  // 1e-16%

        // Calculate expected swap output dynamically
        uint256 expectedAmountOut = curvePool.get_dy(0, 1, 100_000_000e6);

        // Perform a massive swap to stress the virtual price
        vm.prank(RELAYER);
        uint256 amountOut = foreignController.swapCurve(CURVE_POOL, 0, 1, 100_000_000e6, 1000e6);

        assertEq(amountOut, expectedAmountOut);

        // Assert price rises
        uint256 virtualPrice2 = curvePool.get_virtual_price();

        assertGt(virtualPrice2, virtualPrice1);

        // Add one sided liquidity to stress the virtual price
        uint256 totalSupplyBefore = curveLp.totalSupply();
        _addLiquidity(0, 100_000_000e6);
        uint256 totalSupplyAfter = curveLp.totalSupply();

        // Calculate expected virtual price based on the value added and LP tokens minted
        // virtualPrice = totalPoolValue / totalSupply
        // New expected price = (oldPrice * oldSupply + valueAdded) / (oldSupply + newLPTokens)
        uint256[] memory rates = curvePool.stored_rates();
        uint256 valueAdded = 100_000_000e6 * rates[1] / 1e18;  // cgUSD value in 18 decimals

        uint256 expectedVirtualPrice3 = (virtualPrice2 * totalSupplyBefore + valueAdded * 1e18) / totalSupplyAfter;

        uint256 virtualPrice3 = curvePool.get_virtual_price();

        // Assert the calculated virtual price matches expectation (within small tolerance for rounding)
        assertApproxEqRel(virtualPrice3, expectedVirtualPrice3, 0.001e18);  // Within 0.1%
        assertGt(virtualPrice3, virtualPrice2);

        // Remove liquidity
        uint256[] memory minWithdrawAmounts = new uint256[](2);
        minWithdrawAmounts[0] = 1000e6;
        minWithdrawAmounts[1] = 1000e6;

        vm.startPrank(RELAYER);
        foreignController.removeLiquidityCurve(
            CURVE_POOL,
            curveLp.balanceOf(almProxy),
            minWithdrawAmounts
        );
        vm.stopPrank();

        // Assert price rises after liquidity removal (due to fees being distributed to remaining LP holders)
        uint256 virtualPrice4 = curvePool.get_virtual_price();

        // Virtual price should continue to increase slightly due to fee distribution
        assertGt(virtualPrice4, virtualPrice3);
    }

}

contract ForeignController_Curve_E2E_CgUSDUsdcBasePool_Tests is Curve_TestBase {

    function test_e2e_addSwapAndRemoveLiquidityCurve() external {
        // Set a higher slippage to allow for successes
        vm.prank(SPARK_EXECUTOR);
        foreignController.setCurveMaxSlippage(CURVE_POOL, 0.95e18);

        deal(address(usdcBase), almProxy, 1_000_000e6);
        deal(address(cgUSD),    almProxy, 1_000_000e6);

        uint256 initialUsdcBalance  = usdcBase.balanceOf(CURVE_POOL);
        uint256 initialCgUSDBalance = cgUSD.balanceOf(CURVE_POOL);

        // Step 1: Add liquidity

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000e6;
        amounts[1] = 1_000_000e6;

        uint256 minLpAmount = 1_950_000e18;

        assertEq(curveLp.balanceOf(almProxy), 0);

        assertEq(usdcBase.balanceOf(almProxy), 1_000_000e6);
        assertEq(cgUSD.balanceOf(almProxy),    1_000_000e6);

        vm.prank(RELAYER);
        uint256 lpTokensReceived = foreignController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);

        assertEq(curveLp.balanceOf(almProxy), lpTokensReceived);

        assertEq(usdcBase.balanceOf(almProxy), 0);
        assertEq(cgUSD.balanceOf(almProxy),    0);

        assertEq(usdcBase.balanceOf(CURVE_POOL), initialUsdcBalance + 1_000_000e6);
        assertEq(cgUSD.balanceOf(CURVE_POOL),    initialCgUSDBalance + 1_000_000e6);

        // Step 2: Swap cgUSD for USDC

        deal(address(cgUSD), almProxy, 100_000e6);

        assertEq(cgUSD.balanceOf(almProxy),    100_000e6);
        assertEq(usdcBase.balanceOf(almProxy), 0);

        // Calculate expected output dynamically using Curve's get_dy function
        uint256 expectedUsdcOut1 = curvePool.get_dy(1, 0, 100_000e6);

        vm.prank(RELAYER);
        uint256 usdcReturned = foreignController.swapCurve(CURVE_POOL, 1, 0, 100_000e6, 99_900e6);

        assertEq(usdcReturned, expectedUsdcOut1);

        assertEq(usdcBase.balanceOf(almProxy), usdcReturned);
        assertEq(cgUSD.balanceOf(almProxy),    0);

        // Step 3: Swap cgUSD for USDC again (ensure no issues with approval)

        deal(address(cgUSD), almProxy, 100_000e6);

        assertEq(usdcBase.balanceOf(almProxy), usdcReturned);
        assertEq(cgUSD.balanceOf(almProxy),    100_000e6);

        // Calculate expected output for second swap (pool state has changed after first swap)
        uint256 expectedUsdcOut2 = curvePool.get_dy(1, 0, 100_000e6);

        vm.prank(RELAYER);
        uint256 usdcReturnedFromSwap2 = foreignController.swapCurve(CURVE_POOL, 1, 0, 100_000e6, 99_900e6);

        assertEq(usdcReturnedFromSwap2, expectedUsdcOut2);

        usdcReturned += usdcReturnedFromSwap2;

        assertEq(usdcBase.balanceOf(almProxy), usdcReturned);  // Incremented
        assertEq(cgUSD.balanceOf(almProxy),    0);

        // Step 4: Swap USDC for cgUSD

        deal(address(usdcBase), almProxy, 100_000e6);  // NOTE: Overwrites balance

        assertEq(usdcBase.balanceOf(almProxy), 100_000e6);
        assertEq(cgUSD.balanceOf(almProxy),    0);

        // Calculate expected output for swap in opposite direction
        uint256 expectedCgUsdOut = curvePool.get_dy(0, 1, 100_000e6);

        vm.prank(RELAYER);
        uint256 cgUSDReturned = foreignController.swapCurve(CURVE_POOL, 0, 1, 100_000e6, 99_900e6);

        assertEq(cgUSDReturned, expectedCgUsdOut);

        assertEq(usdcBase.balanceOf(almProxy), 0);
        assertEq(cgUSD.balanceOf(almProxy),    cgUSDReturned);

        // Step 5: Remove liquidity

        // Calculate expected pool balances after all swaps:
        // - Started with: initial + 1M from add liquidity
        // - Swap 1: +100k cgUSD, -expectedUsdcOut1 USDC
        // - Swap 2: +100k cgUSD, -expectedUsdcOut2 USDC
        // - Swap 3: +100k USDC, -expectedCgUsdOut cgUSD
        uint256 expectedUsdcBalance  = initialUsdcBalance + 1_000_000e6 - expectedUsdcOut1 - expectedUsdcOut2 + 100_000e6;
        uint256 expectedCgUsdBalance = initialCgUSDBalance + 1_000_000e6 + 100_000e6 + 100_000e6 - expectedCgUsdOut;

        assertEq(usdcBase.balanceOf(CURVE_POOL), expectedUsdcBalance);
        assertEq(cgUSD.balanceOf(CURVE_POOL),    expectedCgUsdBalance);

        // Calculate minimum withdraw amounts dynamically based on current pool state
        uint256[] memory minWithdrawAmounts = _calcMinWithdrawAmounts(lpTokensReceived);

        vm.prank(RELAYER);
        uint256[] memory assetsReceived = foreignController.removeLiquidityCurve(
            CURVE_POOL,
            lpTokensReceived,
            minWithdrawAmounts
        );

        // Verify we received at least the minimum amounts
        assertGe(assetsReceived[0], minWithdrawAmounts[0]);
        assertGe(assetsReceived[1], minWithdrawAmounts[1]);

        // Verify the total value received is reasonable (approximately 2M USD worth)
        uint256 sumAssetsReceived = assetsReceived[0] + assetsReceived[1];
        assertApproxEqAbs(sumAssetsReceived, 2_000_000e6, 100_000e6, "wrong assets received");

        assertEq(usdcBase.balanceOf(almProxy), assetsReceived[0]);
        assertEq(cgUSD.balanceOf(almProxy),    assetsReceived[1] + cgUSDReturned);

        assertEq(curveLp.balanceOf(almProxy), 0);
    }

}
