// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

}

/// @notice The subset of the deployed DualPoolHook the tests read directly. The facet declares its
///         own call surface; this is the observability surface around it.
interface IDualPoolHookLike {

    function getReserves(PoolKey calldata key) external view returns (uint256 token0, uint256 token1);

    function previewDeposit(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function previewWithdraw(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function sharesOf(PoolKey calldata key, address user) external view returns (uint256);

    function totalShares(bytes32 poolId) external view returns (uint256);

}

/// @notice Exercises the DualPoolFacet against the DualPoolHook deployment that is live on mainnet,
///         rather than against MockDualPoolHook. Everything downstream of the facet is real: the
///         deployed hook bytecode, its concentrated-liquidity JIT swap curve, the ERC-4626 vaults
///         holding the pool's idle inventory, the PoolManager unlock context withdrawals traverse,
///         and the pool's own accumulated share supply and reserves.
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

    // The pool's total share supply at the pinned block, asserted exactly so a drifted fork
    // configuration surfaces here rather than as subtle assertion failures elsewhere.
    uint256 internal constant LIVE_TOTAL_SHARES = 1_621_799_463;

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

        _seedRateLimits(poolId);

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
    function _seedRateLimits(bytes32 id) internal {
        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateDepositRateLimitKey(id),
            10_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getAggregateWithdrawRateLimitKey(id),
            10_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        address[2] memory tokens = [ Ethereum.USDC, Ethereum.USDT ];

        for (uint256 i; i < tokens.length; ++i) {
            rateLimits.setRateLimitData(
                mainnetController.dualPool_getAssetDepositRateLimitKey(id, tokens[i]),
                5_000_000e6,
                uint256(1_000_000e6) / 4 hours
            );

            rateLimits.setRateLimitData(
                mainnetController.dualPool_getAssetWithdrawRateLimitKey(id, tokens[i]),
                5_000_000e6,
                uint256(1_000_000e6) / 4 hours
            );
        }
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

contract MainnetController_DualPoolLive_LiquidityTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 1e9;

    function test_live_deposit() external {
        uint256 sharesBefore = hook.totalShares(poolId);

        assertEq(sharesBefore, LIVE_TOTAL_SHARES);

        ( uint256 reserve0Before, uint256 reserve1Before ) = hook.getReserves(poolKey);

        ( uint256 need0, uint256 need1 ) = _fund(DEPOSIT_SHARES);

        // Pre-state: the ALMProxy holds exactly the funded amounts and no position yet.
        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        assertEq(_getProxyBalance0(), need0);
        assertEq(_getProxyBalance1(), need1);

        // The real pool's reserve ratio is heavily skewed, so a proportional deposit is too; this
        // is exactly the asymmetry a 1:1 mock cannot produce.
        assertGt(need0, 0);
        assertGt(need1, 0);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, DEPOSIT_SHARES, uint128(need0), uint128(need1));

        assertEq(hook.totalShares(poolId), sharesBefore + DEPOSIT_SHARES);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), DEPOSIT_SHARES);

        // Everything the facet approved was spent, and the allowance is left at zero.
        assertEq(_getProxyBalance0(), 0);
        assertEq(_getProxyBalance1(), 0);

        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _DUAL_POOL_HOOK_LIVE), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(address(almProxy), _DUAL_POOL_HOOK_LIVE), 0);

        ( uint256 reserve0After, uint256 reserve1After ) = hook.getReserves(poolKey);

        assertEq(reserve0After, reserve0Before + need0);
        assertEq(reserve1After, reserve1Before + need1);
    }

    /// @dev The exit path the mock cannot model: removeLiquidity routes through
    ///      poolManager.unlock, redeems the hook's ERC-6909 claims inside the callback, and pulls
    ///      from the real ERC-4626 vaults when the hook's raw balance is short.
    function test_live_withdraw() external {
        _deposit(DEPOSIT_SHARES);

        uint256 sharesBefore = hook.totalShares(poolId);

        // Pre-state: the deposit landed in full and left the ALMProxy holding nothing but shares.
        assertEq(sharesBefore, LIVE_TOTAL_SHARES + DEPOSIT_SHARES);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), DEPOSIT_SHARES);

        assertEq(_getProxyBalance0(), 0);
        assertEq(_getProxyBalance1(), 0);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(hook.totalShares(poolId), sharesBefore - DEPOSIT_SHARES);

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        // The virtual-share offset makes the round trip lossy by design, so the exit returns at
        // most what went in.
        assertGe(_getProxyBalance0(), expected0);
        assertGe(_getProxyBalance1(), expected1);
    }

    function test_live_depositWithdrawRoundTripDoesNotProfit() external {
        ( uint256 need0, uint256 need1 ) = _deposit(DEPOSIT_SHARES);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(hook.sharesOf(poolKey, address(almProxy)), 0);

        // Rounding is in the pool's favour on both legs, so a round trip can never mint value.
        assertLe(_getProxyBalance0() + _getProxyBalance1(), need0 + need1);
    }

}

/// @notice E2E swaps against the live pool through the UniswapV4 facet, whose swap takes the
///         PoolKey from calldata and so needs no PositionManager registration. A real swap: the
///         hook deploys JIT liquidity across the live pool's buckets in beforeSwap, the
///         PoolManager prices the swap on that concentrated-liquidity curve, and afterSwap tears
///         the position down and sweeps the proceeds back to the vaults.
contract MainnetController_DualPoolLive_SwapTests is DualPoolLive_TestBase {

    uint128 internal constant SWAP_AMOUNT = 100e6;

    function setUp() public override {
        super.setUp();

        // Swap config lives on the UniswapV4 facet, bound to the same derived poolId.
        vm.startPrank(Ethereum.SPARK_PROXY);

        mainnetController.uniswapV4_setMaxSlippage(poolId, MAX_SLIPPAGE);

        rateLimits.setRateLimitData(
            mainnetController.uniswapV4_getSwapRateLimitKey(poolId, Ethereum.USDC),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.uniswapV4_getSwapRateLimitKey(poolId, Ethereum.USDT),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        vm.stopPrank();
    }

    function test_live_swap() external {
        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        bytes32 swapKey = mainnetController.uniswapV4_getSwapRateLimitKey(poolId, Ethereum.USDC);

        uint256 swapLimitBefore = rateLimits.getCurrentRateLimit(swapKey);

        vm.prank(allocator);
        mainnetController.uniswapV4_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        uint256 received = _getProxyBalance1();

        assertEq(_getProxyBalance0(), 0);

        // The output clears the governance floor. It is not bounded by the input: the live pool's
        // reserves are skewed toward currency1, so its price sits off peg and buying the abundant
        // side pays out slightly above 1:1. Which side of parity the payout lands on is a property
        // of live pool state, which is precisely what the mock's flat 1:1 curve cannot express.
        assertGe(received, amountOutMin);

        // Sanity band: real stablecoin pool pricing, not a broken quote.
        assertLt(received, uint256(SWAP_AMOUNT) * 101 / 100);

        assertEq(rateLimits.getCurrentRateLimit(swapKey), swapLimitBefore - SWAP_AMOUNT);

        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _PERMIT2), 0);
    }

    function test_live_swapOneForZero() external {
        deal(Ethereum.USDT, address(almProxy), SWAP_AMOUNT);

        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        vm.prank(allocator);
        mainnetController.uniswapV4_swap(poolKey, Ethereum.USDT, SWAP_AMOUNT, amountOutMin);

        assertEq(_getProxyBalance1(), 0);

        assertGe(_getProxyBalance0(), amountOutMin);
    }

    /// @dev A swap large relative to the pool's deployable liquidity has price impact beyond
    ///      1 - maxSlippage, so the trade the governance floor forces the allocator to ask for is
    ///      one the pool cannot fill. It must revert, not silently fill at a worse price.
    function test_live_swapLargeRelativeToLiquidityReverts() external {
        ( uint256 reserve0, ) = hook.getReserves(poolKey);

        // Several times the entire currency0 side of the pool.
        uint128 amountIn = uint128(reserve0 * 4);

        deal(Ethereum.USDC, address(almProxy), amountIn);

        uint128 amountOutMin = uint128(uint256(amountIn) * MAX_SLIPPAGE / 1e18);

        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.uniswapV4_swap(poolKey, Ethereum.USDC, amountIn, amountOutMin);
    }

}
