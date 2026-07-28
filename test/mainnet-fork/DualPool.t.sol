// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IHooks } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { IFacet }         from "../../src/facets/IFacet.sol";
import { IDualPoolFacet } from "../../src/facets/dual-pool/IDualPoolFacet.sol";

import { MockDualPoolHook } from "../mocks/MockDualPoolHook.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256 allowance);

    function balanceOf(address owner) external view returns (uint256 balance);

}

interface IPermit2Like {

    function allowance(address user, address token, address spender)
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce);

}

abstract contract DualPool_TestBase is ForkTestBase {

    bytes32 internal constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    uint256 internal constant BOOTSTRAP_AMOUNT = 1_000_000e6;
    uint256 internal constant MAX_SLIPPAGE     = 0.99e18;

    // USDC/USDT is a pegged pair, so one unit of currency1 is worth one unit of currency0.
    uint256 internal constant PRICE_RATIO = 1e18;

    address internal freezer = makeAddr("freezer");

    MockDualPoolHook internal hook;

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() public virtual override {
        super.setUp();

        // The DualPool hook is deployed in-place at the flag-encoded address the facet was
        // wired with in the fork test base. The ALMProxy is the hook owner, matching the
        // intended production topology (Sky operating the DualPool deployment it LPs into).
        deployCodeTo(
            "MockDualPoolHook.sol:MockDualPoolHook",
            abi.encode(_UNISWAP_V4_POOL_MANAGER, address(almProxy)),
            _DUAL_POOL_HOOK
        );

        hook = MockDualPoolHook(_DUAL_POOL_HOOK);

        vm.label(_DUAL_POOL_HOOK, "MockDualPoolHook");

        poolKey = PoolKey({
            currency0   : Currency.wrap(Ethereum.USDC),
            currency1   : Currency.wrap(Ethereum.USDT),
            fee         : 100,  // 0.01% in pips
            tickSpacing : 1,
            hooks       : IHooks(_DUAL_POOL_HOOK)
        });

        poolId = keccak256(abi.encode(poolKey));

        vm.startPrank(Ethereum.SPARK_PROXY);

        accessControls.grantRole(FREEZER_ROLE, freezer);

        mainnetController.dualPool_initializePool(poolKey, _defaultConfig());
        mainnetController.dualPool_setMaxSlippage(poolId, MAX_SLIPPAGE);
        mainnetController.dualPool_setPriceRatio(poolId, PRICE_RATIO);

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

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getSwapRateLimitKey(poolId, Ethereum.USDC),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.dualPool_getSwapRateLimitKey(poolId, Ethereum.USDT),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        vm.stopPrank();
    }

    // NOTE: Uniswap V4 deployed to mainnet in January 2025, well before this block.
    function _getBlock() internal pure override returns (uint256) {
        return 23470490;  // September 29, 2025
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _defaultConfig() internal pure returns (IDualPoolFacet.PoolConfig memory config) {
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
            vault0                : makeAddrPure("vault0"),
            vault1                : makeAddrPure("vault1"),
            minDepositBlocks      : 1
        });
    }

    // NOTE: makeAddr is not pure, so config construction uses this derivation instead.
    function makeAddrPure(string memory name) internal pure returns (address addr) {
        addr = vm.addr(uint256(keccak256(abi.encodePacked(name))));
    }

    /// @dev Funds the ALMProxy and runs the admin genesis deposit, then advances one block so
    ///      the minDepositBlocks = 1 lock does not gate the next operation.
    function _bootstrap() internal {
        deal(Ethereum.USDC, address(almProxy), BOOTSTRAP_AMOUNT);
        deal(Ethereum.USDT, address(almProxy), BOOTSTRAP_AMOUNT);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_bootstrap(poolKey, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT);

        vm.roll(block.number + 1);
    }

    /// @dev Allocator deposit sized by the hook's preview, funded to the ALMProxy just in time.
    function _deposit(uint256 shares) internal returns (uint256 need0, uint256 need1) {
        ( need0, need1 ) = hook.previewDeposit(poolKey, shares);

        deal(Ethereum.USDC, address(almProxy), IERC20Like(Ethereum.USDC).balanceOf(address(almProxy)) + need0);
        deal(Ethereum.USDT, address(almProxy), IERC20Like(Ethereum.USDT).balanceOf(address(almProxy)) + need1);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, shares, uint128(need0), uint128(need1));
    }

    function _proxyBalances() internal view returns (uint256 balance0, uint256 balance1) {
        balance0 = IERC20Like(Ethereum.USDC).balanceOf(address(almProxy));
        balance1 = IERC20Like(Ethereum.USDT).balanceOf(address(almProxy));
    }

}

contract MainnetController_DualPool_AdminTests is DualPool_TestBase {

    function test_immutablesAndVersion() external {
        assertEq(mainnetController.dualPool_VERSION(),      "1.0.0");
        assertEq(mainnetController.dualPool_FREEZER_ROLE(), keccak256("FREEZER_ROLE"));
        assertEq(mainnetController.dualPool_hook(),         _DUAL_POOL_HOOK);
        assertEq(mainnetController.dualPool_permit2(),      _PERMIT2);
        assertEq(mainnetController.dualPool_router(),       _UNISWAP_V4_ROUTER);
    }

    function test_initializePool_state() external {
        // setUp initialized the pool through the facet; verify hook-side state landed and the
        // pool is registered on the real PoolManager (a second initialization reverts there).
        MockDualPoolHook.PoolState memory state = hook.getPoolState(poolId);

        assertEq(state.initialized,             true);
        assertEq(state.live,                    false);  // live only after bootstrap
        assertEq(state.externalDepositsEnabled, false);
        assertEq(state.minDepositBlocks,        1);

        // Vault approvals are armed at initialization.
        assertEq(
            IERC20Like(Ethereum.USDC).allowance(_DUAL_POOL_HOOK, makeAddrPure("vault0")),
            type(uint256).max
        );

        vm.expectRevert("MockDualPoolHook/already-initialized");
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_initializePool(poolKey, _defaultConfig());
    }

    function test_bootstrap() external {
        deal(Ethereum.USDC, address(almProxy), BOOTSTRAP_AMOUNT);
        deal(Ethereum.USDT, address(almProxy), BOOTSTRAP_AMOUNT);

        // sqrt(amount0 * amount1) with equal legs mints amount-many shares.
        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolBootstrap(poolId, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_bootstrap(poolKey, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT);

        assertEq(mainnetController.dualPool_getShares(poolKey), BOOTSTRAP_AMOUNT);

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, 0);
        assertEq(balance1, 0);

        // Bootstrap flips the pool live.
        assertEq(hook.getPoolState(poolId).live, true);

        // Approvals are reset after the pull.
        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
    }

    function test_bootstrap_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                allocator,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(allocator);
        mainnetController.dualPool_bootstrap(poolKey, 1e6, 1e6);
    }

    function test_setDistribution() external {
        IDualPoolFacet.LiquidityBucket[] memory buckets = new IDualPoolFacet.LiquidityBucket[](2);

        buckets[0] = IDualPoolFacet.LiquidityBucket({ tickLower : -10, tickUpper : 10, weightBps : 7_500 });
        buckets[1] = IDualPoolFacet.LiquidityBucket({ tickLower : -30, tickUpper : 30, weightBps : 2_500 });

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolDistributionSet(poolId);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setDistribution(poolKey, buckets);
    }

    function test_setExternalDeposits() external {
        assertEq(hook.externalDepositsEnabled(poolId), false);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setExternalDeposits(poolKey, true);

        assertEq(hook.externalDepositsEnabled(poolId), true);
    }

    function test_hookOwnershipHandshake() external {
        address newOwner = makeAddr("newOwner");

        // Offboarding: initiate transfer away from the ALMProxy (Ownable2Step, ineffective
        // until accepted).
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_transferHookOwnership(newOwner);

        assertEq(hook.pendingOwner(), newOwner);
        assertEq(hook.owner(),        address(almProxy));

        vm.prank(newOwner);
        hook.acceptOwnership();

        assertEq(hook.owner(), newOwner);

        // Onboarding: the new owner hands ownership back and the facet accepts on behalf of
        // the ALMProxy.
        vm.prank(newOwner);
        hook.transferOwnership(address(almProxy));

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_acceptHookOwnership();

        assertEq(hook.owner(), address(almProxy));
    }

}

contract MainnetController_DualPool_DepositTests is DualPool_TestBase {

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

    function test_deposit() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        bytes32 aggregateKey = mainnetController.dualPool_getAggregateDepositRateLimitKey(poolId);
        bytes32 asset0Key    = mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDC);
        bytes32 asset1Key    = mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDT);

        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);
        uint256 asset0Before    = rateLimits.getCurrentRateLimit(asset0Key);
        uint256 asset1Before    = rateLimits.getCurrentRateLimit(asset1Key);

        ( uint256 need0, uint256 need1 ) = _deposit(shares);

        assertEq(mainnetController.dualPool_getShares(poolKey), BOOTSTRAP_AMOUNT + shares);

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, 0);
        assertEq(balance1, 0);

        // Asset rate limits decrement by raw 6-decimal amounts; the aggregate rate limit
        // decrements by the 1e18-normalized sum of both legs.
        assertEq(rateLimits.getCurrentRateLimit(asset0Key), asset0Before - need0);
        assertEq(rateLimits.getCurrentRateLimit(asset1Key), asset1Before - need1);

        assertEq(
            rateLimits.getCurrentRateLimit(aggregateKey),
            aggregateBefore - (need0 * 1e12 + need1 * 1e12)
        );

        // Approvals are reset after the pull.
        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(address(almProxy), _DUAL_POOL_HOOK), 0);
    }

    /// @dev A zero-share deposit mints nothing and moves nothing, so every proportional guard is a
    ///      no-op on it, but the hook still re-stamps the ALMProxy's per-pool deposit lock. Left
    ///      open, a compromised allocator could deny withdraw (the only exit) for the price of
    ///      gas, consuming no rate limit budget and leaving the share ledger looking normal.
    function test_deposit_zeroSharesCannotReArmDepositLock() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, shares);

        bytes32 asset0Key = mainnetController.dualPool_getAssetDepositRateLimitKey(poolId, Ethereum.USDC);

        uint256 asset0Before = rateLimits.getCurrentRateLimit(asset0Key);

        vm.expectRevert("DualPoolFacet/zero-shares");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 0, 0, 0);

        assertEq(rateLimits.getCurrentRateLimit(asset0Key), asset0Before);

        // The lock was never re-stamped, so the exit still works in the same block as the attempt.
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, shares, uint128(expected0), uint128(expected1));

        assertEq(mainnetController.dualPool_getShares(poolKey), BOOTSTRAP_AMOUNT - shares);
    }

    function test_deposit_valueFloor() external {
        _bootstrap();

        // 1e18 is the strictest floor governance can set, and the deposit round trip cannot meet
        // it: the hook rounds the deposit up and the redemption down, so the shares minted are
        // always worth marginally less than what was paid. Proves the check binds at the boundary
        // of the legal range rather than at a value setMaxSlippage would now reject.
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 1e18);

        ( uint256 need0, uint256 need1 ) = hook.previewDeposit(poolKey, 100_000e6);

        deal(Ethereum.USDC, address(almProxy), need0);
        deal(Ethereum.USDT, address(almProxy), need1);

        vm.expectRevert("DualPoolFacet/deposit-value-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 100_000e6, uint128(need0), uint128(need1));
    }

    function test_deposit_rateLimitBoundary() external {
        _bootstrap();

        ( uint256 need0, uint256 need1 ) = hook.previewDeposit(poolKey, 100_000e6);

        bytes32 aggregateKey = mainnetController.dualPool_getAggregateDepositRateLimitKey(poolId);

        // Aggregate limit exactly one unit short of the normalized deposit value.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, need0 * 1e12 + need1 * 1e12 - 1, 0);

        deal(Ethereum.USDC, address(almProxy), need0);
        deal(Ethereum.USDT, address(almProxy), need1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 100_000e6, uint128(need0), uint128(need1));

        // At the exact limit the deposit succeeds.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(aggregateKey, need0 * 1e12 + need1 * 1e12, 0);

        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 100_000e6, uint128(need0), uint128(need1));

        assertEq(rateLimits.getCurrentRateLimit(aggregateKey), 0);
    }

    function test_deposit_maxSlippageNotSet() external {
        _bootstrap();

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
    }

}

contract MainnetController_DualPool_WithdrawTests is DualPool_TestBase {

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

    /// @dev The property the setMaxSlippage upper bound exists to guarantee: at the strictest floor
    ///      governance can set, the exit is still reachable. Pool shares are non-transferable and
    ///      removeLiquidity is the only way out, so a floor that no withdrawal could satisfy would
    ///      strand the position. Minimums set exactly to the hook's preview clear the floor by
    ///      equality, and the hook pays precisely that.
    function test_withdraw_atStrictestFloor() external {
        _bootstrap();

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 1e18);

        uint256 shares = 100_000e6;

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, shares);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, shares, uint128(expected0), uint128(expected1));

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, expected0);
        assertEq(balance1, expected1);

        assertEq(mainnetController.dualPool_getShares(poolKey), BOOTSTRAP_AMOUNT - shares);
    }

    function test_withdraw() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, shares);

        bytes32 aggregateKey = mainnetController.dualPool_getAggregateWithdrawRateLimitKey(poolId);

        uint256 aggregateBefore = rateLimits.getCurrentRateLimit(aggregateKey);

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolWithdraw(poolId, shares, expected0, expected1);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, shares, uint128(expected0), uint128(expected1));

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, expected0);
        assertEq(balance1, expected1);

        assertEq(mainnetController.dualPool_getShares(poolKey), BOOTSTRAP_AMOUNT - shares);

        assertEq(
            rateLimits.getCurrentRateLimit(aggregateKey),
            aggregateBefore - (expected0 * 1e12 + expected1 * 1e12)
        );
    }

    function test_withdraw_minsBelowGovernanceFloor() external {
        _bootstrap();

        // A compromised allocator passing zero mins is caught by the maxSlippage floor even
        // though the hook itself would accept them.
        vm.expectRevert("DualPoolFacet/amountMins-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 100_000e6, 0, 0);
    }

    function test_withdraw_sameBlockAsDepositReverts() external {
        _bootstrap();
        _deposit(100_000e6);  // records the deposit block; minDepositBlocks = 1

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, 50_000e6);

        vm.expectRevert("MockDualPoolHook/deposit-locked");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 50_000e6, uint128(expected0), uint128(expected1));

        // Next block the same call succeeds.
        vm.roll(block.number + 1);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 50_000e6, uint128(expected0), uint128(expected1));
    }

}

contract MainnetController_DualPool_SwapTests is DualPool_TestBase {

    uint128 internal constant SWAP_AMOUNT = 10_000e6;

    function test_swap_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, SWAP_AMOUNT);
    }

    function test_swap_notAllocator() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                address(this),
                ALLOCATOR_ROLE
            )
        );

        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, SWAP_AMOUNT);
    }

    function test_swap() external {
        _bootstrap();

        // The mock's stable curve pays 1:1 less the 0.01% pool fee.
        uint128 expectedOut  = SWAP_AMOUNT - SWAP_AMOUNT * poolKey.fee / 1e6;
        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        bytes32 swapKey = mainnetController.dualPool_getSwapRateLimitKey(poolId, Ethereum.USDC);

        uint256 swapLimitBefore = rateLimits.getCurrentRateLimit(swapKey);

        ( , uint256 balance1Before ) = _proxyBalances();

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolSwap(poolId, Ethereum.USDC, Ethereum.USDT, SWAP_AMOUNT, expectedOut);

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, 0);
        assertEq(balance1, balance1Before + expectedOut);

        assertEq(rateLimits.getCurrentRateLimit(swapKey), swapLimitBefore - SWAP_AMOUNT);

        // Permit2 allowance to the router is reset after the swap.
        ( uint160 permitAmount, , ) = IPermit2Like(_PERMIT2).allowance(
            address(almProxy),
            Ethereum.USDC,
            _UNISWAP_V4_ROUTER
        );

        assertEq(permitAmount, 0);

        assertEq(IERC20Like(Ethereum.USDC).allowance(address(almProxy), _PERMIT2), 0);
    }

    function test_swap_amountOutMinBelowFloor() external {
        _bootstrap();

        // Half the input value is far below the 0.99e18 governance floor.
        vm.expectRevert("DualPoolFacet/amountOutMin-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, SWAP_AMOUNT / 2);
    }

    function test_swap_amountOutMinNotMet() external {
        _bootstrap();

        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        // Above the governance floor but above what the pool pays (1:1 less the 0.01% fee), so
        // the router's slippage check reverts inside the swap.
        uint128 amountOutMin = SWAP_AMOUNT - SWAP_AMOUNT * poolKey.fee / 1e6 + 1;

        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);
    }

    function test_swap_oneForZero() external {
        _bootstrap();

        uint128 expectedOut  = SWAP_AMOUNT - SWAP_AMOUNT * poolKey.fee / 1e6;
        uint128 amountOutMin = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        deal(Ethereum.USDT, address(almProxy), SWAP_AMOUNT);

        ( uint256 balance0Before, ) = _proxyBalances();

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDT, SWAP_AMOUNT, amountOutMin);

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, balance0Before + expectedOut);
        assertEq(balance1, 0);
    }

    function test_swap_invalidTokenIn() external {
        _bootstrap();

        vm.expectRevert("DualPoolFacet/invalid-tokenIn");
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDS, SWAP_AMOUNT, SWAP_AMOUNT);
    }

    function test_swap_zeroAmountIn() external {
        _bootstrap();

        vm.expectRevert("DualPoolFacet/zero-amount-in");
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, 0, 0);
    }

    /// @dev The floor is denominated in value, not token counts. With currency1 priced at 2x
    ///      currency0, buying it needs only half as many units to clear the same value bar. That
    ///      is a minimum the parity floor rejects, as the paired assertion shows.
    function test_swap_priceRatioScalesFloorForValuableCurrency1() external {
        _bootstrap();

        uint128 amountOutMin = SWAP_AMOUNT / 2;  // 4,950e6 is the floor at a 2e18 ratio

        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setPriceRatio(poolId, 2e18);

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);

        ( , uint256 balance1 ) = _proxyBalances();

        assertEq(balance1, SWAP_AMOUNT - SWAP_AMOUNT * poolKey.fee / 1e6);

        // Same call under the parity ratio: 9,900e6 is the floor, so half the units is too little.
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setPriceRatio(poolId, PRICE_RATIO);

        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        vm.expectRevert("DualPoolFacet/amountOutMin-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, amountOutMin);
    }

    /// @dev The converse, and the case the audit flagged: with currency1 priced at half of
    ///      currency0, a minimum the parity floor accepts is only ~50% of the input's value. The
    ///      value-denominated floor rejects it and demands ~2x the units instead.
    function test_swap_priceRatioTightensFloorForCheapCurrency1() external {
        _bootstrap();

        uint128 parityFloor = uint128(uint256(SWAP_AMOUNT) * MAX_SLIPPAGE / 1e18);

        deal(Ethereum.USDC, address(almProxy), SWAP_AMOUNT);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setPriceRatio(poolId, 0.5e18);

        vm.expectRevert("DualPoolFacet/amountOutMin-too-low");
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, parityFloor);

        // 19,800e6 clears the value bar, but the mock's 1:1 curve cannot pay it, so the swap now
        // fails inside the router rather than at the governance floor.
        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, SWAP_AMOUNT, parityFloor * 2);
    }

}

contract MainnetController_DualPool_FreezerTests is DualPool_TestBase {

    function test_pausePool_notFreezer() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                allocator,
                FREEZER_ROLE
            )
        );

        vm.prank(allocator);
        mainnetController.dualPool_pausePool(poolKey);
    }

    function test_pausePool_blocksSwapsExitsStayOpen() external {
        _bootstrap();

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolLivenessSet(poolId, false);

        vm.prank(freezer);
        mainnetController.dualPool_pausePool(poolKey);

        // Swaps revert against the paused pool (the hook's revert is wrapped by the
        // PoolManager's hook-call error handling).
        deal(Ethereum.USDC, address(almProxy), 10_000e6);

        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, 10_000e6, 9_950e6);

        // Exits stay open under pause.
        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, 100_000e6);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 100_000e6, uint128(expected0), uint128(expected1));
    }

    function test_resumePool_isAdminOnly() external {
        _bootstrap();

        vm.prank(freezer);
        mainnetController.dualPool_pausePool(poolKey);

        // The freezer path is strictly de-escalatory: no resume.
        vm.expectRevert(
            abi.encodeWithSelector(
                IFacet.AccessControlUnauthorizedAccount.selector,
                freezer,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(freezer);
        mainnetController.dualPool_resumePool(poolKey);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_resumePool(poolKey);

        // Trading works again.
        deal(Ethereum.USDC, address(almProxy), 10_000e6);

        vm.prank(allocator);
        mainnetController.dualPool_swap(poolKey, Ethereum.USDC, 10_000e6, 9_950e6);
    }

    function test_emergencyRevokeVault_exitsStillWork() external {
        _bootstrap();

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolVaultRevoked(poolId);

        vm.prank(freezer);
        mainnetController.dualPool_emergencyRevokeVault(poolKey);

        // Vault allowances are zeroed and the pool is paused with external deposits closed.
        assertEq(IERC20Like(Ethereum.USDC).allowance(_DUAL_POOL_HOOK, makeAddrPure("vault0")), 0);
        assertEq(IERC20Like(Ethereum.USDT).allowance(_DUAL_POOL_HOOK, makeAddrPure("vault1")), 0);

        assertEq(hook.getPoolState(poolId).live,                    false);
        assertEq(hook.getPoolState(poolId).externalDepositsEnabled, false);

        // Exits are unaffected.
        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, BOOTSTRAP_AMOUNT);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, BOOTSTRAP_AMOUNT, uint128(expected0), uint128(expected1));

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);
    }

    function test_refreshVaultApproval_reArmsAfterRevoke() external {
        _bootstrap();

        vm.prank(freezer);
        mainnetController.dualPool_emergencyRevokeVault(poolKey);

        vm.expectEmit(address(mainnetController));
        emit IDualPoolFacet.DualPoolVaultApprovalRefreshed(poolId, Ethereum.USDC);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_refreshVaultApproval(poolKey, poolKey.currency0);

        assertEq(
            IERC20Like(Ethereum.USDC).allowance(_DUAL_POOL_HOOK, makeAddrPure("vault0")),
            type(uint256).max
        );
    }

}

/// @notice Guards the fidelity of MockDualPoolHook against the real DualPoolHook. The rest of this
///         file is only meaningful if the double behaves like the contract it stands in for, so the
///         semantics it deliberately mirrors are asserted here rather than left implicit. The
///         divergences it does not mirror are enumerated at the top of the mock and covered against
///         the real deployed hook in DualPoolLive.t.sol.
contract MainnetController_DualPool_MockFidelityTests is DualPool_TestBase {

    /// @dev The offset is derived from the pair's decimals (average less a 6-decimal margin,
    ///      clamped to [6, 12]), so a 6/6 pair such as USDC/USDT lands on 6.
    function test_mock_decimalsOffsetDerivedFromPairDecimals() external view {
        assertEq(hook.decimalsOffset(poolId), 6);
    }

    /// @dev Conversions must revert on an unbootstrapped pool rather than quoting zero, which is
    ///      what stops the facet's value floor from being satisfied by a vacuous 0 >= 0.
    function test_mock_previewRevertsBeforeBootstrap() external {
        vm.expectRevert("MockDualPoolHook/vault-not-bootstrapped");
        hook.previewWithdraw(poolKey, 1e6);

        vm.expectRevert("MockDualPoolHook/vault-not-bootstrapped");
        hook.previewDeposit(poolKey, 1e6);
    }

    /// @dev The genesis mint is floored at 100 * 10**decimalsOffset so the virtual-share inflation
    ///      defense is meaningful; for this pair that is 100e6 shares.
    function test_mock_bootstrapBelowFloorReverts() external {
        deal(Ethereum.USDC, address(almProxy), BOOTSTRAP_AMOUNT);
        deal(Ethereum.USDT, address(almProxy), BOOTSTRAP_AMOUNT);

        // sqrt(1e6 * 1e6) = 1e6 shares, an order of magnitude under the 1e8 floor.
        vm.expectRevert("MockDualPoolHook/bootstrap-too-small");
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_bootstrap(poolKey, 1e6, 1e6);

        vm.expectRevert("MockDualPoolHook/insufficient-bootstrap");
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_bootstrap(poolKey, 0, BOOTSTRAP_AMOUNT);
    }

    /// @dev The round trip is lossy by construction: the +1 on each balance and the virtual-share
    ///      offset in the denominator, plus rounding up on the way in and down on the way out,
    ///      leave the pool marginally ahead on every deposit.
    function test_mock_shareRoundTripFavoursThePool() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        ( uint256 need0,     uint256 need1     ) = hook.previewDeposit(poolKey, shares);
        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, shares);

        assertLe(expected0, need0);
        assertLe(expected1, need1);
    }

    /// @dev The real hook resolves vaults through a (poolId, currency) mapping, so a currency
    ///      outside the pair is a silent no-op rather than an approval of the wrong token. The
    ///      facet still emits its success event, which is why this is worth pinning down.
    function test_mock_refreshVaultApprovalIsNoOpForOutOfPairCurrency() external {
        address outOfPair = Ethereum.USDS;

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_refreshVaultApproval(poolKey, Currency.wrap(outOfPair));

        IDualPoolFacet.PoolConfig memory config = _defaultConfig();

        assertEq(IERC20Like(outOfPair).allowance(_DUAL_POOL_HOOK, config.vault0), 0);
        assertEq(IERC20Like(outOfPair).allowance(_DUAL_POOL_HOOK, config.vault1), 0);
    }

}
