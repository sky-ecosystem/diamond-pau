// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Currency } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { ApproveLib }                            from "../../libraries/ApproveLib.sol";
import { makeAddressBytes32Key, makeBytes32Key } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IDualPoolFacet } from "./IDualPoolFacet.sol";

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

interface IDualPoolHookLike {

    function addLiquidity(
        PoolKey calldata key,
        uint256 sharesToMint,
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function previewWithdraw(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function removeLiquidity(
        PoolKey calldata key,
        uint256 sharesToBurn,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function sharesOf(PoolKey calldata key, address user) external view returns (uint256);

}

contract DualPoolFacet is IDualPoolFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.DualPoolFacet.v1
    struct FacetStorage {
        mapping (bytes32 poolId => uint256 maxSlippage) maxSlippages;  // 1e18 precision
        mapping (bytes32 poolId => uint256 priceRatio)  priceRatios;   // 1e18 precision
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.DualPoolFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0xf769ffccfd7a265183d98082141e5d486b3011adfd82c88c7c7f901d108bd200;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_DEPOSIT  = keccak256("LIMIT_DUALPOOL_DEPOSIT");
    bytes32 internal constant _LIMIT_WITHDRAW = keccak256("LIMIT_DUALPOOL_WITHDRAW");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    address public immutable override hook;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address hook_) {
        require(hook_ != address(0), "DualPoolFacet/zero-hook");

        hook = hook_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(poolId != bytes32(0), "DualPoolFacet/zero-pool-id");

        // Above 1e18 the floors demand a better-than-perfect round trip, which no honest operation
        // can meet, including withdraw, whose minimums would have to exceed what the hook pays.
        // Since removeLiquidity is the only exit from a non-transferable share position, that would
        // strand the position until a corrective call landed. Bounding here keeps the worst
        // misconfiguration to a blocked deposit, which announces itself and leaves the exit open.
        require(maxSlippage <= 1e18, "DualPoolFacet/max-slippage-too-high");

        emit DualPoolMaxSlippageSet(poolId, _getFacetStorage().maxSlippages[poolId] = maxSlippage);
    }

    /// @inheritdoc IDualPoolFacet
    /// @dev Both this and maxSlippage must be set before allocator operations open, so a pool can
    ///      never be onboarded with a value floor that silently prices its two currencies at
    ///      parity. For a pegged pair the correct value is 1e18.
    function setPriceRatio(bytes32 poolId, uint256 priceRatio)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(poolId != bytes32(0), "DualPoolFacet/zero-pool-id");

        emit DualPoolPriceRatioSet(poolId, _getFacetStorage().priceRatios[poolId] = priceRatio);
    }

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    function deposit(
        PoolKey calldata key,
        uint256 sharesToMint,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        bytes32 poolId = _requireOnboarded(key);

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        address proxy = _getSharedControllerStorage().proxy;

        ApproveLib.approve(token0, proxy, hook, amount0Max);
        ApproveLib.approve(token1, proxy, hook, amount1Max);

        ( uint256 amount0, uint256 amount1 )
            = _addLiquidity(key, proxy, sharesToMint, amount0Max, amount1Max);

        _decreaseRateLimit(
            getAggregateDepositRateLimitKey(poolId),
            _normalizedSum(token0, token1, amount0, amount1)
        );

        _decreaseRateLimit(getAssetDepositRateLimitKey(poolId, token0), amount0);
        _decreaseRateLimit(getAssetDepositRateLimitKey(poolId, token1), amount1);

        _requireDepositValue(key, poolId, token0, token1, sharesToMint, amount0, amount1);

        ApproveLib.approve(token0, proxy, hook, 0);
        ApproveLib.approve(token1, proxy, hook, 0);

        emit DualPoolDeposit(poolId, sharesToMint, amount0, amount1);
    }

    /// @inheritdoc IDualPoolFacet
    function withdraw(
        PoolKey calldata key,
        uint256 sharesToBurn,
        uint128 amount0Min,
        uint128 amount1Min
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        bytes32 poolId = _requireOnboarded(key);

        require(sharesToBurn != 0, "DualPoolFacet/zero-shares");

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        _requireWithdrawValue(key, poolId, token0, token1, sharesToBurn, amount0Min, amount1Min);

        ( uint256 amount0, uint256 amount1 ) = _removeLiquidity(
            key,
            _getSharedControllerStorage().proxy,
            sharesToBurn,
            amount0Min,
            amount1Min
        );

        _decreaseRateLimit(
            getAggregateWithdrawRateLimitKey(poolId),
            _normalizedSum(token0, token1, amount0, amount1)
        );

        _decreaseRateLimit(getAssetWithdrawRateLimitKey(poolId, token0), amount0);
        _decreaseRateLimit(getAssetWithdrawRateLimitKey(poolId, token1), amount1);

        emit DualPoolWithdraw(poolId, sharesToBurn, amount0, amount1);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    function getAggregateDepositRateLimitKey(bytes32 poolId) public pure override returns (bytes32) {
        return makeBytes32Key(_LIMIT_DEPOSIT, poolId);
    }

    /// @inheritdoc IDualPoolFacet
    function getAggregateWithdrawRateLimitKey(bytes32 poolId) public pure override returns (bytes32) {
        return makeBytes32Key(_LIMIT_WITHDRAW, poolId);
    }

    /// @inheritdoc IDualPoolFacet
    function getAssetDepositRateLimitKey(bytes32 poolId, address token)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressBytes32Key(_LIMIT_DEPOSIT, token, poolId);
    }

    /// @inheritdoc IDualPoolFacet
    function getAssetWithdrawRateLimitKey(bytes32 poolId, address token)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressBytes32Key(_LIMIT_WITHDRAW, token, poolId);
    }

    /// @inheritdoc IDualPoolFacet
    function getMaxSlippage(bytes32 poolId) external view override returns (uint256) {
        return _getFacetStorage().maxSlippages[poolId];
    }

    /// @inheritdoc IDualPoolFacet
    function getPriceRatio(bytes32 poolId) external view override returns (uint256) {
        return _getFacetStorage().priceRatios[poolId];
    }

    /// @inheritdoc IDualPoolFacet
    function getShares(PoolKey calldata key) external view override returns (uint256) {
        return IDualPoolHookLike(hook).sharesOf(key, _getSharedControllerStorage().proxy);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    /// @notice Calls the hook's addLiquidity through the ALMProxy and measures what it actually
    ///         spent by balance difference, so the rate limits and value floor operate on real
    ///         amounts rather than the hook's return values.
    function _addLiquidity(
        PoolKey calldata key,
        address proxy,
        uint256 sharesToMint,
        uint128 amount0Max,
        uint128 amount1Max
    )
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        uint256 startingBalance0 = _getBalance(token0, proxy);
        uint256 startingBalance1 = _getBalance(token1, proxy);

        IALMProxy(proxy).doCall(
            hook,
            abi.encodeCall(
                IDualPoolHookLike.addLiquidity,
                (key, sharesToMint, amount0Max, amount1Max, block.timestamp)
            )
        );

        amount0 = _clampedSub(startingBalance0, _getBalance(token0, proxy));
        amount1 = _clampedSub(startingBalance1, _getBalance(token1, proxy));
    }

    /// @notice Calls the hook's removeLiquidity through the ALMProxy and measures what the
    ///         ALMProxy actually received by balance difference.
    function _removeLiquidity(
        PoolKey calldata key,
        address proxy,
        uint256 sharesToBurn,
        uint128 amount0Min,
        uint128 amount1Min
    )
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        uint256 startingBalance0 = _getBalance(token0, proxy);
        uint256 startingBalance1 = _getBalance(token1, proxy);

        IALMProxy(proxy).doCall(
            hook,
            abi.encodeCall(
                IDualPoolHookLike.removeLiquidity,
                (key, sharesToBurn, amount0Min, amount1Min, block.timestamp)
            )
        );

        amount0 = _getBalance(token0, proxy) - startingBalance0;
        amount1 = _getBalance(token1, proxy) - startingBalance1;
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _clampedSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        return a > b ? a - b : 0;
    }

    function _getBalance(address token, address account) internal view returns (uint256 balance) {
        return IERC20Like(token).balanceOf(account);
    }

    function _getNormalizedBalance(address token, uint256 balance)
        internal
        view
        returns (uint256 normalizedBalance)
    {
        return balance * 1e18 / (10 ** IERC20Like(token).decimals());
    }

    function _normalizedSum(address token0, address token1, uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256)
    {
        return _getNormalizedBalance(token0, amount0) + _getNormalizedBalance(token1, amount1);
    }

    /// @notice Value of a currency pair amount, denominated in currency0 and scaled by 1e18 on top
    ///         of the 18-decimal normalization. priceRatio prices one whole unit of currency1 in
    ///         whole units of currency0 (1e18 = parity), so the two legs become comparable even
    ///         when the pair is not pegged. The extra 1e18 keeps the weighting division-free, so
    ///         the price never truncates a leg. Extreme ratios can overflow, which reverts and so
    ///         fails closed.
    function _pairValue(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 priceRatio
    )
        internal
        view
        returns (uint256)
    {
        return _getNormalizedBalance(token0, amount0) * 1e18
            +  _getNormalizedBalance(token1, amount1) * priceRatio;
    }

    /// @notice Round-trip value floor for a deposit: the shares just minted must be redeemable, pro
    ///         rata at current state, for at least maxSlippage of the value paid. This is what
    ///         catches share-price skew (donation-style manipulation, vault share-price moves, hook
    ///         mis-accounting) that the caller's amountMax caps cannot express. A compromised
    ///         allocator cannot weaken it.
    function _requireDepositValue(
        PoolKey calldata key,
        bytes32 poolId,
        address token0,
        address token1,
        uint256 sharesToMint,
        uint256 amount0,
        uint256 amount1
    )
        internal
        view
    {
        FacetStorage storage $ = _getFacetStorage();

        uint256 priceRatio = $.priceRatios[poolId];

        ( uint256 preview0, uint256 preview1 ) = IDualPoolHookLike(hook).previewWithdraw(key, sharesToMint);

        require(
            _pairValue(token0, token1, preview0, preview1, priceRatio) * 1e18 >=
            _pairValue(token0, token1, amount0, amount1, priceRatio) * $.maxSlippages[poolId],
            "DualPoolFacet/deposit-value-too-low"
        );
    }

    /// @notice Governance value floor over the allocator's withdrawal minimums: the ALLOCATOR_ROLE
    ///         is assumed compromisable, so its minimums cannot be the only guard. Comparing
    ///         aggregates is deliberate: the token split of a withdrawal moves with pool price
    ///         while the pool's total value does not, so the floor is denominated in value.
    function _requireWithdrawValue(
        PoolKey calldata key,
        bytes32 poolId,
        address token0,
        address token1,
        uint256 sharesToBurn,
        uint128 amount0Min,
        uint128 amount1Min
    )
        internal
        view
    {
        FacetStorage storage $ = _getFacetStorage();

        uint256 priceRatio = $.priceRatios[poolId];

        ( uint256 expected0, uint256 expected1 ) = IDualPoolHookLike(hook).previewWithdraw(key, sharesToBurn);

        require(
            _pairValue(token0, token1, amount0Min, amount1Min, priceRatio) * 1e18 >=
            _pairValue(token0, token1, expected0, expected1, priceRatio) * $.maxSlippages[poolId],
            "DualPoolFacet/amountMins-too-low"
        );
    }

    function _requireHookPool(PoolKey calldata key) internal view returns (bytes32 poolId) {
        require(address(key.hooks) == hook, "DualPoolFacet/invalid-hook");

        poolId = keccak256(abi.encode(key));
    }

    /// @notice Validates that a pool is onboarded for allocator operations, which requires both
    ///         halves of the value floor to be configured: a max slippage and a currency price
    ///         ratio. Requiring the ratio is what stops a pool from being onboarded with floors
    ///         that silently price its two currencies at parity. The _require*Value helpers re-read
    ///         the config from storage when they run.
    function _requireOnboarded(PoolKey calldata key) internal view returns (bytes32 poolId) {
        poolId = _requireHookPool(key);

        FacetStorage storage $ = _getFacetStorage();

        require($.maxSlippages[poolId] != 0, "DualPoolFacet/max-slippage-not-set");
        require($.priceRatios[poolId]  != 0, "DualPoolFacet/price-ratio-not-set");
    }

}
