// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { BalanceDelta } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { Currency }     from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }      from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { SwapParams }   from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolOperation.sol";

import { TickMath }              from "../../lib/uniswap-v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { TransientStateLibrary } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/libraries/TransientStateLibrary.sol";

import { IHooks }       from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

import {
    IUnlockCallback
} from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/callback/IUnlockCallback.sol";

import { IFacet }         from "../../src/facets/IFacet.sol";
import { IDualPoolFacet } from "../../src/facets/dual-pool/IDualPoolFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function transfer(address to, uint256 amount) external;

}

interface IERC4626Like {

    function balanceOf(address) external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

}

interface IERC6909Like {

    function balanceOf(address owner, uint256 id) external view returns (uint256);

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

    function vaults(bytes32 poolId, Currency currency) external view returns (address);
    
    function totalAssets(PoolKey calldata key) external view returns (uint256 amount0, uint256 amount1);

}

/// @notice Minimal Uniswap V4 unlock caller: runs a sequence of exact-input swap legs against one
///         pool inside a single `unlock` and settles the net from its own balance at the end.
///         Production routers settle each leg before starting the next one, and none of them expose
///         a per-leg price limit, which is what the attack tests below need.
contract DualPoolSwapper is IUnlockCallback {

    using TransientStateLibrary for IPoolManager;

    struct Leg {
        bool    zeroForOne;
        uint256 amountIn;  // Zero consumes the preceding leg's entire output.
        uint160 limit;     // sqrtPriceX96 at which the leg stops executing.
    }

    IPoolManager internal immutable poolManager;

    constructor(address poolManager_) {
        poolManager = IPoolManager(poolManager_);
    }

    function swap(PoolKey calldata key, Leg[] calldata legs) external {
        poolManager.unlock(abi.encode(key, legs));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "DualPoolSwapper/not-pool-manager");

        ( PoolKey memory key, Leg[] memory legs ) = abi.decode(data, (PoolKey, Leg[]));

        uint256 amountIn;

        for (uint256 i; i < legs.length; ++i) {
            amountIn = legs[i].amountIn == 0 ? amountIn : legs[i].amountIn;

            BalanceDelta delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne        : legs[i].zeroForOne,
                    amountSpecified   : -int256(amountIn),
                    sqrtPriceLimitX96 : legs[i].limit
                }),
                ""
            );

            amountIn = uint256(uint128(legs[i].zeroForOne ? delta.amount1() : delta.amount0()));
        }

        _settle(key.currency0);
        _settle(key.currency1);

        return "";
    }

    function _settle(Currency currency) internal {
        int256 delta = poolManager.currencyDelta(address(this), currency);

        if (delta < 0) {
            poolManager.sync(currency);
            IERC20Like(Currency.unwrap(currency)).transfer(address(poolManager), uint256(-delta));
            poolManager.settle();
        } else if (delta > 0) {
            poolManager.take(currency, address(this), uint256(delta));
        }
    }

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

    // NOTE: The live DualPoolHook, whose inventory accounting reads `vault.maxWithdraw()` rather
    //       than `vault.previewRedeem()`. Verified onchain: the hook is owned by its incumbent
    //       operator and the USDC/USDT pool below is bootstrapped, live and permissionless at the
    //       pinned block.
    address internal constant _DUAL_POOL_HOOK = 0x0000005bb4DF4109bF356a585C8b8Ea70FCbAaC0;

    uint256 internal constant MAX_SLIPPAGE = 0.99e18;

    IDualPoolHookLike internal hook = IDualPoolHookLike(_DUAL_POOL_HOOK);

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() public virtual override {
        super.setUp();

        vm.label(_DUAL_POOL_HOOK, "DualPoolHook");

        // The live USDC/USDT pool. Reconstructed rather than hardcoded so poolId stays derived.
        poolKey = PoolKey({
            currency0   : Currency.wrap(Ethereum.USDC),
            currency1   : Currency.wrap(Ethereum.USDT),
            fee         : 10,  // 0.001% in pips
            tickSpacing : 10,
            hooks       : IHooks(_DUAL_POOL_HOOK)
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

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    /// @dev Must be called while pranking SPARK_PROXY.
    function _seedRateLimits() internal {
        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateDepositRateLimitKey(poolId),
            20_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDC),
            10_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDT),
            10_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateWithdrawRateLimitKey(poolId),
            20_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDC),
            10_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAssetWithdrawRateLimitKey(poolId, Ethereum.USDT),
            10_000_000e6,
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

    function _getHookAssets(address token) internal view returns (uint256 balance, uint256 claims, uint256 vaulted) {
        balance = IERC20Like(token).balanceOf(address(hook));

        claims = IERC6909Like(_UNISWAP_V4_POOL_MANAGER).balanceOf(
            address(hook),
            uint256(uint160(token))
        );

        IERC4626Like vault = IERC4626Like(hook.vaults(poolId, Currency.wrap(token)));

        vaulted = vault.convertToAssets(vault.balanceOf(address(hook)));
    }

}

contract MainnetController_DualPoolLive_DepositTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 5_000_000e6;

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

    function test_deposit_maxSlippageNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
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

    function test_deposit_depositValueTooLowBoundary() external {
        // The hook rounds the deposit up and the redemption down, so the shares minted are always
        // worth marginally less than what was paid.
        uint256 expectedSlippage = 0.999999999999798566e18;

        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, expectedSlippage + 1);

        vm.expectRevert("DualPoolFacet/deposit-value-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, expectedSlippage);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));
    }

    function test_deposit() external {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);
        deal(Ethereum.USDT, address(almProxy), 500_000e6);

        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        assertEq(need0, 2_272_673.253282e6);
        assertEq(need1, 7_656_142.985180e6);

        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);
        uint256 asset0Before    = rateLimits.getCurrentRateLimit(asset0Key);
        uint256 asset1Before    = rateLimits.getCurrentRateLimit(asset1Key);

        // Pre-state: the ALMProxy holds exactly the funded amounts and no position yet.
        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        assertEq(_getProxyBalance0(), 1_000_000e6 + need0);
        assertEq(_getProxyBalance1(), 500_000e6 + need1);

        ( uint256 balance0, uint256 claims0, uint256 vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( uint256 balance1, uint256 claims1, uint256 vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(balance0, 0);
        assertEq(claims0,  444.137819e6);
        assertEq(vaulted0, 293.480767e6);

        assertEq(balance1, 0);
        assertEq(claims1,  0);
        assertEq(vaulted1, 2_484.876944e6);

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

        uint256 startingAssets0 = balance0 + claims0 + vaulted0;
        uint256 startingAssets1 = balance1 + claims1 + vaulted1;

        ( balance0, claims0, vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( balance1, claims1, vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(balance0, 0);
        assertEq(claims0,  444.137819e6); // Claims left unclaimed.
        assertEq(vaulted0, 293.480767e6 + need0);

        assertEq(balance1, 0);
        assertEq(claims1,  0);
        assertEq(vaulted1, 2_484.876944e6 + need1);

        // Vault assets owned by the hook increased by the deposited amounts.
        assertEq(balance0 + claims0 + vaulted0, startingAssets0 + need0);
        assertEq(balance1 + claims1 + vaulted1, startingAssets1 + need1);

        // Approvals are reset after the pull.
        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
    }

}

contract MainnetController_DualPoolLive_WithdrawTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 5_000_000e6;

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

    function test_withdraw_maxSlippageNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 1e6, 0, 0);
    }

    function test_withdraw_minAmountsTooLowBoundary() external {
        _deposit(DEPOSIT_SHARES);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        uint256 expectedSlippage = 1e18;

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, expectedSlippage + 1);

        vm.expectRevert("DualPoolFacet/min-amounts-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, expectedSlippage);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));
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

        assertEq(expected0, 2_272_673.253281e6);
        assertEq(expected1, 7_656_142.985179e6);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(_getProxyBalance0(), expected0);
        assertEq(_getProxyBalance1(), expected1);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);
    }

    /// @dev `removeLiquidity` routes through `poolManager.unlock`, redeems the hook's ERC-6909
    ///      claims inside the callback, and pulls from the real ERC-4626 vaults when the hook's
    ///      raw balance is short.
    function test_withdraw() external {
        _deposit(DEPOSIT_SHARES);

        uint256 asset0Before    = rateLimits.getCurrentRateLimit(asset0Key);
        uint256 asset1Before    = rateLimits.getCurrentRateLimit(asset1Key);
        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), DEPOSIT_SHARES);

        assertEq(_getProxyBalance0(), 0);
        assertEq(_getProxyBalance1(), 0);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        assertEq(expected0, 2_272_673.253281e6);
        assertEq(expected1, 7_656_142.985179e6);

        ( uint256 balance0, uint256 claims0, uint256 vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( uint256 balance1, uint256 claims1, uint256 vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(balance0, 0);
        assertEq(claims0,  444.137819e6);
        assertEq(vaulted0, 2_272_966.734049e6);

        assertEq(balance1, 0);
        assertEq(claims1,  0);
        assertEq(vaulted1, 7_658_627.862124e6);

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

        uint256 startingAssets0 = balance0 + claims0 + vaulted0;
        uint256 startingAssets1 = balance1 + claims1 + vaulted1;

        ( balance0, claims0, vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( balance1, claims1, vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(balance0, 0);
        assertEq(claims0,  0);
        assertEq(vaulted0, 2_272_966.734049e6 + 444.137819e6 - expected0); // Claims claimed.

        assertEq(balance1, 0);
        assertEq(claims1,  0);
        assertEq(vaulted1, 7_658_627.862124e6 - expected1);

        // Vault assets owned by the hook decreased by at most the withdrawn amounts.
        assertEq(balance0 + claims0 + vaulted0, startingAssets0 - expected0);
        assertEq(balance1 + claims1 + vaulted1, startingAssets1 - expected1);
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

contract MainnetController_DualPoolLive_AttacksTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 5_000_000e6;

    // Sized past the whole book so the first leg runs to its price limit instead of out of input.
    uint256 internal constant ATTACK_IN = 20_000_000e6;

    uint256 internal constant SWAPPER_FUNDING = 20_000_000e6;

    DualPoolSwapper internal swapper;

    // Every bucket in the live distribution sits inside [-60, 60], so a limit one tick range
    // beyond it exhausts that side's JIT liquidity without walking the whole tick bitmap.
    uint160 internal drainDown;  // sqrtPriceAtTick(-120)
    uint160 internal drainUp;    // sqrtPriceAtTick(120)

    function setUp() public override {
        super.setUp();

        swapper = new DualPoolSwapper(_UNISWAP_V4_POOL_MANAGER);

        drainDown = TickMath.getSqrtPriceAtTick(-120);
        drainUp   = TickMath.getSqrtPriceAtTick(120);

        deal(Ethereum.USDC, address(swapper), SWAPPER_FUNDING);
        deal(Ethereum.USDT, address(swapper), SWAPPER_FUNDING);
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    /// @dev Sells USDC down to the bottom price limit and sends the entire USDT proceeds straight
    ///      back, all inside one `unlock` with a single net settlement at the end.
    function _roundTrip() internal {
        DualPoolSwapper.Leg[] memory legs = new DualPoolSwapper.Leg[](2);

        legs[0] = DualPoolSwapper.Leg({ zeroForOne: true,  amountIn: ATTACK_IN, limit: drainDown });
        legs[1] = DualPoolSwapper.Leg({ zeroForOne: false, amountIn: 0,         limit: drainUp   });

        swapper.swap(poolKey, legs);
    }

    function _swap(bool zeroForOne, uint256 amountIn) internal {
        DualPoolSwapper.Leg[] memory legs = new DualPoolSwapper.Leg[](1);

        legs[0] = DualPoolSwapper.Leg({
            zeroForOne : zeroForOne,
            amountIn   : amountIn,
            limit      : zeroForOne ? drainDown : drainUp
        });

        swapper.swap(poolKey, legs);
    }

    // raw + claims + vaulted
    function _getHookTotalAssets() internal view returns (uint256 total0, uint256 total1) {
        ( total0, total1 ) = hook.totalAssets(poolKey);
    }

    function _getSwapperBalance0() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDC).balanceOf(address(swapper));
    }

    function _getSwapperBalance1() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDT).balanceOf(address(swapper));
    }

    function test_e2e_roundTripInOneUnlock_evictsBothVaultsIntoClaims() external {
        _deposit(DEPOSIT_SHARES);

        ( , uint256 claims0, uint256 vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( , uint256 claims1, uint256 vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(claims0,  444.137819e6);
        assertEq(vaulted0, 2_272_966.734049e6);

        assertEq(claims1,  0);
        assertEq(vaulted1, 7_658_627.862124e6);

        // Force the PoolManager below every claim so `_unbackedClaims` reports the whole balance as
        // unbacked and the second swap cannot spend the first swap's claims.
        deal(Ethereum.USDC, _UNISWAP_V4_POOL_MANAGER, 0);
        deal(Ethereum.USDT, _UNISWAP_V4_POOL_MANAGER, 0);

        _roundTrip();

        ( , claims0, vaulted0 ) = _getHookAssets(Ethereum.USDC);
        ( , claims1, vaulted1 ) = _getHookAssets(Ethereum.USDT);

        assertEq(claims0,  6_655_559.671619e6);
        assertEq(vaulted0, 2);

        // The second swap prices below every bucket, where the JIT book is USDC-only, so it never
        // touches the USDT vault. This residue is the USDT the first swap did not deploy; only a
        // swap whose book needs USDT could pull it, and neither leg of this round trip does.
        assertEq(claims1,  2_272_989.463939e6);
        assertEq(vaulted1, 1_005_465.638448e6);

        assertEq(_getSwapperBalance0(), SWAPPER_FUNDING - 4_382_148.799760e6); // paid in
        assertEq(_getSwapperBalance1(), SWAPPER_FUNDING + 4_380_172.759727e6); // extracted USDT

        // Net normalized cost of the sequence, in this fabricated state only.
        uint256 cost = ( SWAPPER_FUNDING - _getSwapperBalance0() )
                     - ( _getSwapperBalance1() - SWAPPER_FUNDING );

        assertEq(cost, 1_976.040033e6);
    }

}
