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

    function approve(address spender, uint256 amount) external;

    function balanceOf(address owner) external view returns (uint256 balance);

}

abstract contract DualPool_TestBase is ForkTestBase {

    uint256 internal constant BOOTSTRAP_AMOUNT = 1_000_000e6;
    uint256 internal constant MAX_SLIPPAGE     = 0.99e18;

    // USDC/USDT is a pegged pair, so one unit of currency1 is worth one unit of currency0.
    uint256 internal constant PRICE_RATIO = 1e18;

    MockDualPoolHook internal hook;

    PoolKey internal poolKey;

    bytes32 internal poolId;

    function setUp() public virtual override {
        super.setUp();

        // The DualPool hook is deployed in-place at the flag-encoded address the facet was wired
        // with in the fork test base. Governance (the Spark Proxy) is the hook owner and the pool
        // is permissionless, matching the intended production topology: pool lifecycle is operated
        // by governance directly on the hook, and the ALMProxy enters and exits as a regular LP
        // through the facet.
        deployCodeTo(
            "MockDualPoolHook.sol:MockDualPoolHook",
            abi.encode(_UNISWAP_V4_POOL_MANAGER, Ethereum.SPARK_PROXY),
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

        hook.initializePool(poolKey, _defaultConfig());

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

        vm.stopPrank();
    }

    // NOTE: Uniswap V4 deployed to mainnet in January 2025, well before this block.
    function _getBlock() internal pure override returns (uint256) {
        return 23470490;  // September 29, 2025
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _badHookKey() internal view returns (PoolKey memory badKey) {
        badKey = poolKey;
        badKey.hooks = IHooks(address(0xBAD));
    }

    function _defaultConfig() internal pure returns (MockDualPoolHook.PoolConfig memory config) {
        MockDualPoolHook.LiquidityBucket[] memory distribution =
            new MockDualPoolHook.LiquidityBucket[](1);

        distribution[0] = MockDualPoolHook.LiquidityBucket({
            tickLower : -10,
            tickUpper : 10,
            weightBps : 10_000
        });

        config = MockDualPoolHook.PoolConfig({
            sqrtPriceX96          : 79228162514264337593543950336,  // 2**96, price of 1.0
            distribution          : distribution,
            allowExternalDeposits : true,  // permissionless pool; the ALMProxy is a regular LP
            vault0                : makeAddrPure("vault0"),
            vault1                : makeAddrPure("vault1"),
            minDepositBlocks      : 1
        });
    }

    // NOTE: makeAddr is not pure, so config construction uses this derivation instead.
    function makeAddrPure(string memory name) internal pure returns (address addr) {
        addr = vm.addr(uint256(keccak256(abi.encodePacked(name))));
    }

    /// @dev Governance genesis deposit, made directly on the hook it owns, then advances one block
    ///      so the minDepositBlocks = 1 lock does not gate the next operation. Bootstrap shares
    ///      belong to governance; the ALMProxy's position starts at zero.
    function _bootstrap() internal {
        deal(Ethereum.USDC, Ethereum.SPARK_PROXY, BOOTSTRAP_AMOUNT);
        deal(Ethereum.USDT, Ethereum.SPARK_PROXY, BOOTSTRAP_AMOUNT);

        vm.startPrank(Ethereum.SPARK_PROXY);

        IERC20Like(Ethereum.USDC).approve(_DUAL_POOL_HOOK, BOOTSTRAP_AMOUNT);
        IERC20Like(Ethereum.USDT).approve(_DUAL_POOL_HOOK, BOOTSTRAP_AMOUNT);

        hook.bootstrap(poolKey, BOOTSTRAP_AMOUNT, BOOTSTRAP_AMOUNT);

        vm.stopPrank();

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

    function test_deposit_invalidHook() external {
        vm.expectRevert("DualPoolFacet/invalid-hook");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(_badHookKey(), 1e6, 1e6, 1e6);
    }

    function test_deposit_maxSlippageNotSet() external {
        _bootstrap();

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 0);

        vm.expectRevert("DualPoolFacet/max-slippage-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_deposit(poolKey, 1e6, 1e6, 1e6);
    }

    function test_deposit_priceRatioNotSet() external {
        _bootstrap();

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setPriceRatio(poolId, 0);

        vm.expectRevert("DualPoolFacet/price-ratio-not-set");
        vm.prank(allocator);
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

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);

        ( uint256 need0, uint256 need1 ) = _deposit(shares);

        assertEq(mainnetController.dualPool_getShares(poolKey), shares);

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

    function test_withdraw_priceRatioNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setPriceRatio(poolId, 0);

        vm.expectRevert("DualPoolFacet/price-ratio-not-set");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 1e6, 0, 0);
    }

    function test_withdraw_zeroShares() external {
        vm.expectRevert("DualPoolFacet/zero-shares");
        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, 0, 0, 0);
    }

    /// @dev The property the setMaxSlippage upper bound exists to guarantee: at the strictest floor
    ///      governance can set, the exit is still reachable. Pool shares are non-transferable and
    ///      removeLiquidity is the only way out, so a floor that no withdrawal could satisfy would
    ///      strand the position. Minimums set exactly to the hook's preview clear the floor by
    ///      equality, and the hook pays precisely that.
    function test_withdraw_atStrictestFloor() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        _deposit(shares);

        vm.roll(block.number + 1);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.dualPool_setMaxSlippage(poolId, 1e18);

        ( uint256 expected0, uint256 expected1 ) = hook.previewWithdraw(poolKey, shares);

        vm.prank(allocator);
        mainnetController.dualPool_withdraw(poolKey, shares, uint128(expected0), uint128(expected1));

        ( uint256 balance0, uint256 balance1 ) = _proxyBalances();

        assertEq(balance0, expected0);
        assertEq(balance1, expected1);

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);
    }

    function test_withdraw() external {
        _bootstrap();

        uint256 shares = 100_000e6;

        _deposit(shares);

        vm.roll(block.number + 1);

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

        assertEq(mainnetController.dualPool_getShares(poolKey), 0);

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
        // sqrt(1e6 * 1e6) = 1e6 shares, an order of magnitude under the 1e8 floor.
        vm.expectRevert("MockDualPoolHook/bootstrap-too-small");
        vm.prank(Ethereum.SPARK_PROXY);
        hook.bootstrap(poolKey, 1e6, 1e6);

        vm.expectRevert("MockDualPoolHook/insufficient-bootstrap");
        vm.prank(Ethereum.SPARK_PROXY);
        hook.bootstrap(poolKey, 0, BOOTSTRAP_AMOUNT);
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

}
