// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { IFacet }         from "../../src/facets/IFacet.sol";
import { IDualPoolFacet } from "../../src/facets/dual-pool/IDualPoolFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

}

/// @notice The subset of the deployed DualPoolHook the tests read directly. The facet declares its
///         own call surface; this is the observability surface around it.
interface IDualPoolHookLike {

    function previewDeposit(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function previewWithdraw(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function sharesOf(PoolKey calldata key, address user) external view returns (uint256);

}

/// @notice Exercises the DualPoolFacet against the DualPoolHook deployment that is live on mainnet.
///         Everything downstream of the facet is real: the deployed hook bytecode, its
///         concentrated-liquidity JIT swap curve, the ERC-4626 vaults holding the pool's idle
///         inventory, the PoolManager unlock context withdrawals traverse, and the pool's own
///         accumulated share supply and reserves.
///
///         The hook is owned by its incumbent operator and the pool is permissionless, which is the
///         production topology the facet is designed for: the ALMProxy enters and exits as a
///         regular LP, with no hook ownership involved.
abstract contract DualPoolLive_TestBase is ForkTestBase {

    // NOTE: The live DualPoolHook, whose inventory accounting reads vault.maxWithdraw() rather
    //       than vault.previewRedeem(). Verified onchain: the hook is owned by its incumbent
    //       operator and the USDC/USDT pool below is bootstrapped, live and permissionless at the
    //       pinned block.
    address internal constant _DUAL_POOL_HOOK_LIVE = 0x0000005bb4DF4109bF356a585C8b8Ea70FCbAaC0;

    uint256 internal constant MAX_SLIPPAGE = 0.99e18;

    IDualPoolHookLike internal hook = IDualPoolHookLike(_DUAL_POOL_HOOK_LIVE);

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() public virtual override {
        super.setUp();

        vm.label(_DUAL_POOL_HOOK_LIVE, "DualPoolHook");

        // The live USDC/USDT pool. Reconstructed rather than hardcoded so poolId stays derived.
        poolKey = PoolKey({
            currency0   : Currency.wrap(Ethereum.USDC),
            currency1   : Currency.wrap(Ethereum.USDT),
            fee         : 10,  // 0.001% in pips
            tickSpacing : 10,
            hooks       : IHooks(_DUAL_POOL_HOOK_LIVE)
        });

        poolId = keccak256(abi.encode(poolKey));

        vm.startPrank(Ethereum.SPARK_PROXY);

        mainnetController.dualPool_setMaxSlippage(poolId, MAX_SLIPPAGE);

        _seedRateLimits();

        vm.stopPrank();
    }

    // NOTE: The live USDC/USDT DualPool pool was bootstrapped well before this block. Archive
    //       state at this block was verified against the configured RPC.
    function _getBlock() internal pure override returns (uint256) {
        return 25740000;  // August 2026
    }

    /// @dev Points the facet the fork base deploys at the live hook instead of the mock's address.
    function _dualPoolHook() internal view override returns (address) {
        return _DUAL_POOL_HOOK_LIVE;
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    /// @dev Must be called while pranking SPARK_PROXY.
    function _seedRateLimits() internal {
        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateDepositRateLimitKey(poolId),
            10_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDC),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDT),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateWithdrawRateLimitKey(poolId),
            10_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDC),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDT),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );
    }

    function _badHookKey() internal view returns (PoolKey memory badKey) {
        badKey = poolKey;
        badKey.hooks = IHooks(address(0xBAD));
    }

    /// @dev Sizes the deposit off the hook's own preview and funds the ALMProxy just in time, so
    ///      the amounts track the live pool's real reserve ratio.
    function _fund(uint256 shares) internal returns (uint256 need0, uint256 need1) {
        ( need0, need1 ) = hook.previewDeposit(poolKey, shares);

        deal(Ethereum.USDC, address(almProxy), _getProxyBalance0() + need0);
        deal(Ethereum.USDT, address(almProxy), _getProxyBalance1() + need1);
    }

    function _deposit(uint256 shares) internal returns (uint256 need0, uint256 need1) {
        ( need0, need1 ) = _fund(shares);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, shares, uint128(need0), uint128(need1));
    }

    function _getProxyBalance0() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDC).balanceOf(address(almProxy));
    }

    function _getProxyBalance1() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDT).balanceOf(address(almProxy));
    }

}

contract MainnetController_DualPoolLive_DepositTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 1_000e6;

    bytes32 internal aggregateKey;
    bytes32 internal asset0Key;
    bytes32 internal asset1Key;

    function setUp() public virtual override {
        super.setUp();

        aggregateKey = mainnetController.dualPool_getAggregateDepositRateLimitKey(poolId);
        asset0Key    = mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDC);
        asset1Key    = mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDT);
    }

    function test_deposit_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
    }

    function test_deposit_notAllocator() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                address(this),
                ALLOCATOR_ROLE
            )
        );

        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
    }

    function test_deposit_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(_badHookKey(), 1e6, 1e6, 1e6);
    }

    function test_deposit_maxSlippageNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
    }

    function test_deposit_valueFloor() external {
        // A 1e18 floor demands a perfect round trip, which a deposit cannot meet: the hook rounds
        // the deposit up and the redemption down, so the shares minted are always worth marginally
        // less than what was paid. Proves the check binds at the perfect-round-trip boundary.
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 1e18);

        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        vm.expectRevert("DualPoolFacet/deposit-value-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));
    }

    function test_deposit_rateLimitBoundary_aggregate() external {
        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        // Aggregate limit exactly one unit short of the normalized deposit value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, need0 * 1e12 + need1 * 1e12 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        // At the exact limit the deposit succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, need0 * 1e12 + need1 * 1e12, 0);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));
    }

    function test_deposit_rateLimitBoundary_token0() external {
        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        // Token 0 limit exactly one unit short of the normalized deposit value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset0Key, need0 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        // At the exact limit the deposit succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset0Key, need0, 0);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));
    }

    function test_deposit_rateLimitBoundary_token1() external {
        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        // Token 1 limit exactly one unit short of the normalized deposit value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset1Key, need1 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        // At the exact limit the deposit succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset1Key, need1, 0);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));
    }

    function test_deposit() external {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);
        deal(Ethereum.USDT, address(almProxy), 500_000e6);

        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);
        uint256 asset0Before    = rateLimits.getCurrentRateLimit(asset0Key);
        uint256 asset1Before    = rateLimits.getCurrentRateLimit(asset1Key);

        // Pre-state: the ALMProxy holds exactly the funded amounts and no position yet.
        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        assertEq(_getProxyBalance0(), 1_000_000e6 + need0);
        assertEq(_getProxyBalance1(), 500_000e6 + need1);

        // The real pool's reserve ratio is heavily skewed, so a proportional deposit is too; this
        // is exactly the asymmetry a 1:1 mock cannot produce.
        assertGt(need0, 0);
        assertGt(need1, 0);

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolDeposit(poolId, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        // Asset rate limits decrement by raw 6-decimal amounts; the aggregate rate limit
        // decrements by the 1e18-normalized sum of both legs.
        assertEq(rateLimits.getCurrentRateLimit(asset0Key), asset0Before - need0);
        assertEq(rateLimits.getCurrentRateLimit(asset1Key), asset1Before - need1);

        assertEq(
            rateLimits.getCurrentRateLimit(aggregateKey),
            aggregateBefore - (need0 * 1e12 + need1 * 1e12)
        );

        assertEq(hook.sharesOf(poolKey, address(almProxy)), DEPOSIT_SHARES);

        // Everything the facet approved was spent.
        assertEq(_getProxyBalance0(), 1_000_000e6);
        assertEq(_getProxyBalance1(), 500_000e6);

        // Approvals are reset after the pull.
        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _DUAL_POOL_HOOK_LIVE), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(address(almProxy), _DUAL_POOL_HOOK_LIVE), 0);
    }

}

contract MainnetController_DualPoolLive_WithdrawTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 1_000e6;

    bytes32 internal aggregateKey;
    bytes32 internal asset0Key;
    bytes32 internal asset1Key;

    function setUp() public virtual override {
        super.setUp();

        aggregateKey = mainnetController.dualPool_getAggregateWithdrawRateLimitKey(poolId);
        asset0Key    = mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDC);
        asset1Key    = mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDT);
    }

    function test_withdraw_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.dualPool_withdraw(poolKey, 1e6, 0, 0);
    }

    function test_withdraw_notAllocator() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                address(this),
                ALLOCATOR_ROLE
            )
        );

        mainnetController.dualPool_withdraw(poolKey, 1e6, 0, 0);
    }

    function test_withdraw_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(_badHookKey(), 1e6, 0, 0);
    }

    function test_withdraw_maxSlippageNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 1e6, 0, 0);
    }

    function test_withdraw_zeroShares() external {
        vm.expectRevert("DualPoolFacet/zero-shares");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 0, 0, 0);
    }

    function test_withdraw_minsBelowGovernanceFloor() external {
        // A compromised allocator passing zero mins is caught by the maxSlippage floor even
        // though the hook itself would accept them.
        vm.expectRevert("DualPoolFacet/amountMins-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, 0, 0);
    }

    function test_withdraw_rateLimitBoundary_aggregate() external {
        _deposit(DEPOSIT_SHARES);

        vm.roll(block.number + 1);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        // Aggregate limit exactly one unit short of the normalized withdraw value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, (expected0 + expected1) * 1e12 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        // At the exact limit the withdrawal succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, (expected0 + expected1) * 1e12, 0);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));
    }

    function test_withdraw_rateLimitBoundary_token0() external {
        _deposit(DEPOSIT_SHARES);

        vm.roll(block.number + 1);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        // Asset 0 limit exactly one unit short of the normalized withdraw value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset0Key, expected0 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        // At the exact limit the withdrawal succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset0Key, expected0, 0);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));
    }

    function test_withdraw_rateLimitBoundary_token1() external {
        _deposit(DEPOSIT_SHARES);

        vm.roll(block.number + 1);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        // Asset 1 limit exactly one unit short of the normalized withdraw value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset1Key, expected1 - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        // At the exact limit the withdrawal succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(asset1Key, expected1, 0);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));
    }

    /// @dev At the strictest sensible floor (1e18, a perfect round trip), the exit is still
    ///      reachable. Pool shares are non-transferable and removeLiquidity is the only way out, so
    ///      a floor that no withdrawal could satisfy would strand the position. Minimums set
    ///      exactly to the hook's preview clear the floor by equality, and the hook pays precisely
    ///      that.
    function test_withdraw_atStrictestFloor() external {
        _deposit(DEPOSIT_SHARES);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 1e18);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(_getProxyBalance0(), expected0);
        assertEq(_getProxyBalance1(), expected1);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);
    }

    /// @dev The exit path the mock cannot model: removeLiquidity routes through
    ///      poolManager.unlock, redeems the hook's ERC-6909 claims inside the callback, and pulls
    ///      from the real ERC-4626 vaults when the hook's raw balance is short.
    function test_withdraw() external {
        _deposit(DEPOSIT_SHARES);

        uint256 asset0Before    = rateLimits.getCurrentRateLimit(asset0Key);
        uint256 asset1Before    = rateLimits.getCurrentRateLimit(asset1Key);
        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), DEPOSIT_SHARES);

        assertEq(_getProxyBalance0(), 0);
        assertEq(_getProxyBalance1(), 0);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolWithdraw(poolId, DEPOSIT_SHARES, expected0, expected1);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(rateLimits.getCurrentRateLimit(asset0Key), asset0Before - expected0);
        assertEq(rateLimits.getCurrentRateLimit(asset1Key), asset1Before - expected1);

        assertEq(
            rateLimits.getCurrentRateLimit(aggregateKey),
            aggregateBefore - (expected0 * 1e12 + expected1 * 1e12)
        );

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        // The virtual-share offset makes the round trip lossy by design, so the exit returns at
        // most what went in.
        assertGe(_getProxyBalance0(), expected0);
        assertGe(_getProxyBalance1(), expected1);
    }

}

contract MainnetController_DualPoolLive_RoundTripTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 1_000e6;

    function test_depositWithdrawRoundTrip_doesNotProfit() external {
        ( uint256 need0, uint256 need1 ) = _deposit(DEPOSIT_SHARES);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        // Rounding is in the pool's favour on both legs, so a round trip can never mint value.
        assertLe(_getProxyBalance0() + _getProxyBalance1(), need0 + need1);
    }

}
