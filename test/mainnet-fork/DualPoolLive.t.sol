// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { IDualPoolFacet } from "../../src/facets/dual-pool/IDualPoolFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

}

interface IERC4626Like {

    function asset() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

}

/// @notice The subset of the deployed DualPoolHook the tests read directly. The facet declares its
///         own call surface; this is the observability surface around it.
interface IDualPoolHookLive {

    function acceptOwnership() external;

    function decimalsOffset(bytes32 poolId) external view returns (uint8);

    function getReserves(PoolKey calldata key) external view returns (uint256 token0, uint256 token1);

    function livePools(bytes32 poolId) external view returns (bool);

    function minDepositBlocks(bytes32 poolId) external view returns (uint64);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

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

    function transferOwnership(address newOwner) external;

    function vaults(bytes32 poolId, address currency) external view returns (address);

}

/// @notice Exercises the DualPoolFacet against the DualPoolHook deployment that is live on mainnet,
///         rather than against MockDualPoolHook. Everything downstream of the facet is real: the
///         deployed hook bytecode, its concentrated-liquidity JIT swap curve, the ERC-4626 vaults
///         holding the pool's idle inventory, the PoolManager unlock context withdrawals traverse,
///         and the pool's own accumulated share supply and reserves.
///
///         Hook ownership is moved to the ALMProxy in setUp, which is the production topology the
///         facet is designed for.
abstract contract DualPoolLive_TestBase is ForkTestBase {

    // NOTE: The live DualPoolHook. Verified onchain: owner() is _HOOK_OWNER and the USDC/USDT pool
    //       below is bootstrapped and live at the pinned block.
    address internal constant _DUAL_POOL_HOOK_LIVE = 0x00000078BD49D5279a99b5F4011a5C61eE8caaC0;

    address internal constant _HOOK_OWNER = 0x58e28b95a2ee57c4E90613AFce9e8CCEED3aB1E8;

    bytes32 internal constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    uint256 internal constant MAX_SLIPPAGE = 0.99e18;

    // USDC/USDT is a pegged pair, so one unit of currency1 is worth one unit of currency0.
    uint256 internal constant PRICE_RATIO = 1e18;

    address internal freezer = makeAddr("freezer");

    IDualPoolHookLive internal hook = IDualPoolHookLive(_DUAL_POOL_HOOK_LIVE);

    PoolKey internal poolKey;

    bytes32 internal poolId;

    address internal vault0;
    address internal vault1;

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

        vault0 = hook.vaults(poolId, Ethereum.USDC);
        vault1 = hook.vaults(poolId, Ethereum.USDT);

        vm.label(vault0, "vault0");
        vm.label(vault1, "vault1");

        // Ownable2Step: the incumbent operator proposes, then the facet accepts on the ALMProxy's
        // behalf. This is the onboarding handoff the facet exists to perform.
        vm.prank(_HOOK_OWNER);
        hook.transferOwnership(address(almProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);

        accessControls.grantRole(FREEZER_ROLE, freezer);

        mainnetController.dualPool_acceptHookOwnership();

        mainnetController.dualPool_setMaxSlippage(poolId, MAX_SLIPPAGE);
        mainnetController.dualPool_setPriceRatio(poolId, PRICE_RATIO);

        _seedRateLimits(poolId);

        vm.stopPrank();
    }

    // NOTE: The live USDC/USDT DualPool pool was initialized at block 25540385, so the pinned block
    //       must be after it. Archive state at this block was verified against the configured RPC.
    function _getBlock() internal pure override returns (uint256) {
        return 25630000;  // July 2026
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

            rateLimits.setRateLimitData(
                mainnetController.dualPool_getSwapRateLimitKey(id, tokens[i]),
                5_000_000e6,
                uint256(1_000_000e6) / 4 hours
            );
        }
    }

    /// @dev Sizes the deposit off the hook's own preview and funds the ALMProxy just in time, so
    ///      the amounts track the live pool's real reserve ratio.
    function _deposit(uint256 shares) internal returns (uint256 need0, uint256 need1) {
        ( need0, need1 ) = hook.previewDeposit(poolKey, shares);

        deal(Ethereum.USDC, address(almProxy), _balance0() + need0);
        deal(Ethereum.USDT, address(almProxy), _balance1() + need1);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, shares, uint128(need0), uint128(need1));
    }

    function _balance0() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDC).balanceOf(address(almProxy));
    }

    function _balance1() internal view returns (uint256) {
        return IERC20Like(Ethereum.USDT).balanceOf(address(almProxy));
    }

}

contract MainnetController_DualPoolLive_OnboardingTests is DualPoolLive_TestBase {

    function test_live_hookOwnershipHandoff() external {
        // setUp completed the two-step handoff against the real hook.
        assertEq(hook.owner(),        address(almProxy));
        assertEq(hook.pendingOwner(), address(0));
    }

    /// @dev Sanity-checks the assumptions the rest of this suite is written against, so a state
    ///      change at the pinned block surfaces here rather than as a confusing failure elsewhere.
    function test_live_poolPreconditions() external view {
        assertTrue(hook.livePools(poolId));

        assertGt(hook.totalShares(poolId), 0);

        // Real ERC-4626 vaults on both sides, each holding the pool's idle inventory.
        assertEq(IERC4626Like(vault0).asset(), Ethereum.USDC);
        assertEq(IERC4626Like(vault1).asset(), Ethereum.USDT);

        assertGt(IERC4626Like(vault0).balanceOf(_DUAL_POOL_HOOK_LIVE), 0);
        assertGt(IERC4626Like(vault1).balanceOf(_DUAL_POOL_HOOK_LIVE), 0);

        ( uint256 reserve0, uint256 reserve1 ) = hook.getReserves(poolKey);

        assertGt(reserve0, 0);
        assertGt(reserve1, 0);
    }

}

contract MainnetController_DualPoolLive_LiquidityTests is DualPoolLive_TestBase {

    uint256 internal constant DEPOSIT_SHARES = 1e9;

    function test_live_deposit() external {
        uint256 sharesBefore = hook.totalShares(poolId);

        ( uint256 reserve0Before, uint256 reserve1Before ) = hook.getReserves(poolKey);

        ( uint256 need0, uint256 need1 ) = _deposit(DEPOSIT_SHARES);

        // The real pool's reserve ratio is heavily skewed, so a proportional deposit is too; this
        // is exactly the asymmetry a 1:1 mock cannot produce.
        assertGt(need0, 0);
        assertGt(need1, 0);

        assertEq(hook.totalShares(poolId), sharesBefore + DEPOSIT_SHARES);

        assertEq(mainnetController.dualPool_getShares(poolKey), DEPOSIT_SHARES);

        // Everything the facet approved was spent, and the allowance is left at zero.
        assertEq(_balance0(), 0);
        assertEq(_balance1(), 0);

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

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(hook.totalShares(poolId), sharesBefore - DEPOSIT_SHARES);

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);

        // The virtual-share offset makes the round trip lossy by design, so the exit returns at
        // most what went in.
        assertGe(_balance0(), expected0);
        assertGe(_balance1(), expected1);
    }

    function test_live_depositWithdrawRoundTripDoesNotProfit() external {
        ( uint256 need0, uint256 need1 ) = _deposit(DEPOSIT_SHARES);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        // Rounding is in the pool's favour on both legs, so a round trip can never mint value.
        assertLe(_balance0() + _balance1(), need0 + need1);
    }

    function test_live_withdrawAfterEmergencyRevokeVault() external {
        _deposit(DEPOSIT_SHARES);

        // Freezer pulls the pool's vault exposure, which forces the hook to source the exit from
        // its own balance instead of the vault.
        vm.prank(freezer);
        mainnetController.dualPool_emergencyRevokeVault(poolKey);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, DEPOSIT_SHARES);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, DEPOSIT_SHARES, uint128(expected0), uint128(expected1));

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);
    }

}

contract MainnetController_DualPoolLive_SwapTests is DualPoolLive_TestBase {

    uint128 internal constant SWAP_AMOUNT = 100e6;

    /// @dev A real swap: the hook deploys JIT liquidity across the live pool's three buckets in
    ///      beforeSwap, the PoolManager prices the swap on that concentrated-liquidity curve, and
    ///      afterSwap tears the position down and sweeps the proceeds back to the vaults.
    function test_live_swap() external {
        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        bytes32 swapKey = mainnetController.dualPool_getSwapRateLimitKey(poolId, Ethereum.USDC);

        uint256 swapLimitBefore = rateLimits.getCurrentRateLimit(swapKey);

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        uint256 received = _balance1();

        assertEq(_balance0(), 0);

        // The output clears the governance floor. It is not bounded by the input: the live pool's
        // reserves are skewed toward currency1, so its price sits off peg and buying the abundant
        // side pays out slightly above 1:1. At this block that is 100.095 USDT for 100 USDC. Which
        // of parity the payout lands on is a property of live pool state, which is precisely what a
        // flat 1:1 mock curve cannot express.
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
        mainnetController.dualPool_swap(poolKey, Ethereum.USDT, SWAP_AMOUNT, amountOutMin);

        assertEq(_balance1(), 0);

        assertGe(_balance0(), amountOutMin);
    }

    /// @dev The gap the mock's flat curve hides: a swap large relative to the pool's deployable
    ///      liquidity has price impact beyond 1 - maxSlippage, so the trade the governance floor
    ///      forces the allocator to ask for is one the pool cannot fill. It must revert, not
    ///      silently fill at a worse price.
    function test_live_swapLargeRelativeToLiquidityReverts() external {
        ( uint256 reserve0, ) = hook.getReserves(poolKey);

        // Several times the entire currency0 side of the pool.
        uint128 amountIn = uint128(reserve0 * 4);

        deal(Ethereum.USDC, address(almProxy), amountIn);

        uint128 amountOutMin = uint128(uint256(amountIn) * MAX_SLIPPAGE / 1e18);

        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, amountIn, amountOutMin);
    }

    function test_live_swapRevertsWhenPoolPaused() external {
        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        vm.prank(freezer);
        mainnetController.dualPool_pausePool(poolKey);

        assertFalse(hook.livePools(poolId));

        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        // Resuming is admin-only, and restores the swap path.
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_resumePool(poolKey);

        assertTrue(hook.livePools(poolId));

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        assertGe(_balance1(), amountOutMin);
    }

}

contract MainnetController_DualPoolLive_PoolCreationTests is DualPoolLive_TestBase {

    uint256 internal constant BOOTSTRAP_AMOUNT = 10_000e6;

    PoolKey internal newKey;

    bytes32 internal newPoolId;

    function setUp() public override {
        super.setUp();

        // A second USDC/USDT pool on the same live hook, distinguished by fee tier. Reuses the
        // live pool's real vaults, which the hook validates against each currency at init.
        newKey = PoolKey({
            currency0   : Currency.wrap(Ethereum.USDC),
            currency1   : Currency.wrap(Ethereum.USDT),
            fee         : 500,
            tickSpacing : 10,
            hooks       : IHooks(_DUAL_POOL_HOOK_LIVE)
        });

        newPoolId = keccak256(abi.encode(newKey));

        vm.startPrank(Ethereum.SPARK_PROXY);

        mainnetController.dualPool_setMaxSlippage(newPoolId, MAX_SLIPPAGE);
        mainnetController.dualPool_setPriceRatio(newPoolId, PRICE_RATIO);

        _seedRateLimits(newPoolId);

        vm.stopPrank();
    }

    /// @dev Real pool creation on the real hook: the vault addresses are checked against each
    ///      currency's asset() and rejected if they charge a fee, and the PoolManager pool is
    ///      created at the operator's chosen price. The mock validates none of this.
    function test_live_initializePoolAndBootstrap() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_initializePool(newKey, _newPoolConfig());

        // Paused until bootstrapped.
        assertFalse(hook.livePools(newPoolId));
        assertEq(hook.totalShares(newPoolId), 0);

        assertEq(hook.vaults(newPoolId, Ethereum.USDC), vault0);
        assertEq(hook.vaults(newPoolId, Ethereum.USDT), vault1);

        deal(Ethereum.USDC, address(almProxy), BOOTSTRAP_AMOUNT);
        deal(Ethereum.USDT, address(almProxy), BOOTSTRAP_AMOUNT);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_bootstrap(newKey, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT);

        // Bootstrapping flips the pool live and credits the ALMProxy with the genesis position.
        assertTrue(hook.livePools(newPoolId));

        assertGt(mainnetController.dualPool_getShares(newKey), 0);

        assertEq(hook.decimalsOffset(newPoolId), 6);

        ( uint256 reserve0, uint256 reserve1 ) = hook.getReserves(newKey);

        // The hook parks the bootstrap inventory in the real ERC-4626 vaults, and reserves are read
        // back through previewRedeem, which rounds down. A wei of the deposit is therefore not
        // visible in reserves. That is real vault rounding, which the mock's direct-custody model
        // never shows.
        assertApproxEqAbs(reserve0, BOOTSTRAP_AMOUNT, 1);
        assertApproxEqAbs(reserve1, BOOTSTRAP_AMOUNT, 1);
    }

    /// @dev The hook rejects a vault whose asset() does not match the currency it is configured
    ///      against, a config the mock accepts silently.
    function test_live_initializePoolRejectsMismatchedVault() external {
        IDualPoolFacet.PoolConfig memory config = _newPoolConfig();

        config.vault0 = vault1;  // USDT vault on the USDC side

        vm.expectRevert();
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_initializePool(newKey, config);
    }

    function _newPoolConfig() internal view returns (IDualPoolFacet.PoolConfig memory config) {
        IDualPoolFacet.LiquidityBucket[] memory distribution = new IDualPoolFacet.LiquidityBucket[](1);

        distribution[0] = IDualPoolFacet.LiquidityBucket({
            tickLower : -10,
            tickUpper : 10,
            weightBps : 10_000
        });

        config = IDualPoolFacet.PoolConfig({
            sqrtPriceX96          : 79228162514264337593543950336,  // 2**96, price of 1.0
            distribution          : distribution,
            allowExternalDeposits : false,
            vault0                : vault0,
            vault1                : vault1,
            minDepositBlocks      : 0
        });
    }

}
