// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Currency } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IV4Router } from "../../../lib/uniswap-v4-periphery/src/interfaces/IV4Router.sol";
import { Actions }   from "../../../lib/uniswap-v4-periphery/src/libraries/Actions.sol";

import { ApproveLib }                            from "../../libraries/ApproveLib.sol";
import { makeAddressBytes32Key, makeBytes32Key } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IDualPoolFacet } from "./IDualPoolFacet.sol";

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

interface IPermit2Like {

    function approve(address token, address spender, uint160 amount, uint48 expiration) external;

}

interface IUniversalRouterLike {

    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external;

}

interface IDualPoolHookLike {

    function acceptOwnership() external;

    function addLiquidity(
        PoolKey calldata key,
        uint256 sharesToMint,
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function bootstrap(PoolKey calldata key, uint256 amount0, uint256 amount1)
        external
        returns (uint256 shares);

    function emergencyRevokeVault(PoolKey calldata key) external;

    function initializePool(PoolKey calldata key, IDualPoolFacet.PoolConfig calldata config)
        external
        returns (int24 tick);

    function previewWithdraw(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    function refreshVaultApproval(PoolKey calldata key, Currency currency) external;

    function removeLiquidity(
        PoolKey calldata key,
        uint256 sharesToBurn,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

    function setDistribution(PoolKey calldata key, IDualPoolFacet.LiquidityBucket[] calldata buckets)
        external;

    function setExternalDeposits(PoolKey calldata key, bool enabled) external;

    function setPoolLive(PoolKey calldata key, bool live) external;

    function sharesOf(PoolKey calldata key, address user) external view returns (uint256);

    function transferOwnership(address newOwner) external;

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
    bytes32 internal constant _LIMIT_SWAP     = keccak256("LIMIT_DUALPOOL_SWAP");
    bytes32 internal constant _LIMIT_WITHDRAW = keccak256("LIMIT_DUALPOOL_WITHDRAW");

    /// @inheritdoc IDualPoolFacet
    bytes32 public constant override FREEZER_ROLE = keccak256("FREEZER_ROLE");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    uint256 internal constant _V4_SWAP = 0x10;

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    address public immutable override hook;

    /// @inheritdoc IDualPoolFacet
    address public immutable override permit2;

    /// @inheritdoc IDualPoolFacet
    address public immutable override router;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address hook_, address permit2_, address router_) {
        require(hook_    != address(0), "DualPoolFacet/zero-hook");
        require(permit2_ != address(0), "DualPoolFacet/zero-permit2");
        require(router_  != address(0), "DualPoolFacet/zero-router");

        hook    = hook_;
        permit2 = permit2_;
        router  = router_;
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

    /// @inheritdoc IDualPoolFacet
    function initializePool(PoolKey calldata key, PoolConfig calldata config)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        bytes memory result = _doCall(hook, abi.encodeCall(IDualPoolHookLike.initializePool, (key, config)));

        emit DualPoolPoolInitialized(poolId, abi.decode(result, (int24)));
    }

    /// @inheritdoc IDualPoolFacet
    function bootstrap(PoolKey calldata key, uint256 amount0, uint256 amount1)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        ApproveLib.approve(token0, _getSharedControllerStorage().proxy, hook, amount0);
        ApproveLib.approve(token1, _getSharedControllerStorage().proxy, hook, amount1);

        uint256 startingBalance0 = _getProxyBalance(token0);
        uint256 startingBalance1 = _getProxyBalance(token1);

        bytes memory result
            = _doCall(hook, abi.encodeCall(IDualPoolHookLike.bootstrap, (key, amount0, amount1)));

        uint256 spent0 = _clampedSub(startingBalance0, _getProxyBalance(token0));
        uint256 spent1 = _clampedSub(startingBalance1, _getProxyBalance(token1));

        ApproveLib.approve(token0, _getSharedControllerStorage().proxy, hook, 0);
        ApproveLib.approve(token1, _getSharedControllerStorage().proxy, hook, 0);

        emit DualPoolBootstrap(poolId, abi.decode(result, (uint256)), spent0, spent1);
    }

    /// @inheritdoc IDualPoolFacet
    function setDistribution(PoolKey calldata key, LiquidityBucket[] calldata buckets)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.setDistribution, (key, buckets)));

        emit DualPoolDistributionSet(poolId);
    }

    /// @inheritdoc IDualPoolFacet
    function setExternalDeposits(PoolKey calldata key, bool enabled)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.setExternalDeposits, (key, enabled)));

        emit DualPoolExternalDepositsSet(poolId, enabled);
    }

    /// @inheritdoc IDualPoolFacet
    function resumePool(PoolKey calldata key)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.setPoolLive, (key, true)));

        emit DualPoolLivenessSet(poolId, true);
    }

    /// @inheritdoc IDualPoolFacet
    function refreshVaultApproval(PoolKey calldata key, Currency currency)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.refreshVaultApproval, (key, currency)));

        emit DualPoolVaultApprovalRefreshed(poolId, Currency.unwrap(currency));
    }

    /// @inheritdoc IDualPoolFacet
    function acceptHookOwnership() external override nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        _doCall(hook, abi.encodeCall(IDualPoolHookLike.acceptOwnership, ()));

        emit DualPoolHookOwnershipAccepted();
    }

    /// @inheritdoc IDualPoolFacet
    function transferHookOwnership(address newOwner)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newOwner != address(0), "DualPoolFacet/zero-new-owner");

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.transferOwnership, (newOwner)));

        emit DualPoolHookOwnershipTransferInitiated(newOwner);
    }

    /**********************************************************************************************/
    /*** External Interactive Freezer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    /// @dev Resuming re-arms swap exposure, so it is admin-only while pausing is the freezer's
    ///      lever; the freezer path stays strictly de-escalatory.
    function pausePool(PoolKey calldata key) external override nonReentrant onlyRole(FREEZER_ROLE) {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.setPoolLive, (key, false)));

        emit DualPoolLivenessSet(poolId, false);
    }

    /// @inheritdoc IDualPoolFacet
    function emergencyRevokeVault(PoolKey calldata key)
        external
        override
        nonReentrant
        onlyRole(FREEZER_ROLE)
    {
        bytes32 poolId = _requireHookPool(key);

        _doCall(hook, abi.encodeCall(IDualPoolHookLike.emergencyRevokeVault, (key)));

        emit DualPoolVaultRevoked(poolId);
    }

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc IDualPoolFacet
    function deposit(PoolKey calldata key, uint256 sharesToMint, uint128 amount0Max, uint128 amount1Max)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        ( bytes32 poolId, , ) = _requireOnboarded(key);

        // A zero-share deposit mints nothing and moves nothing, so every proportional guard below
        // is a no-op on it, but the hook still re-stamps the ALMProxy's per-pool deposit lock. That
        // would let a compromised allocator deny withdraw (the only exit) for the price of gas.
        require(sharesToMint != 0, "DualPoolFacet/zero-shares");

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        ApproveLib.approve(token0, _getSharedControllerStorage().proxy, hook, amount0Max);
        ApproveLib.approve(token1, _getSharedControllerStorage().proxy, hook, amount1Max);

        uint256 amount0;
        uint256 amount1;

        {
            uint256 startingBalance0 = _getProxyBalance(token0);
            uint256 startingBalance1 = _getProxyBalance(token1);

            _doCall(
                hook,
                abi.encodeCall(
                    IDualPoolHookLike.addLiquidity,
                    (key, sharesToMint, amount0Max, amount1Max, block.timestamp)
                )
            );

            amount0 = _clampedSub(startingBalance0, _getProxyBalance(token0));
            amount1 = _clampedSub(startingBalance1, _getProxyBalance(token1));
        }

        _decreaseRateLimit(getAggregateDepositRateLimitKey(poolId), _normalizedSum(token0, token1, amount0, amount1));
        _decreaseRateLimit(getAssetDepositRateLimitKey(poolId, token0), amount0);
        _decreaseRateLimit(getAssetDepositRateLimitKey(poolId, token1), amount1);

        _requireDepositValue(key, poolId, token0, token1, sharesToMint, amount0, amount1);

        ApproveLib.approve(token0, _getSharedControllerStorage().proxy, hook, 0);
        ApproveLib.approve(token1, _getSharedControllerStorage().proxy, hook, 0);

        emit DualPoolDeposit(poolId, sharesToMint, amount0, amount1);
    }

    /// @inheritdoc IDualPoolFacet
    function withdraw(PoolKey calldata key, uint256 sharesToBurn, uint128 amount0Min, uint128 amount1Min)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        ( bytes32 poolId, , ) = _requireOnboarded(key);

        require(sharesToBurn != 0, "DualPoolFacet/zero-shares");

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        _requireWithdrawValue(key, poolId, token0, token1, sharesToBurn, amount0Min, amount1Min);

        uint256 startingBalance0 = _getProxyBalance(token0);
        uint256 startingBalance1 = _getProxyBalance(token1);

        _doCall(
            hook,
            abi.encodeCall(
                IDualPoolHookLike.removeLiquidity,
                (key, sharesToBurn, amount0Min, amount1Min, block.timestamp)
            )
        );

        uint256 amount0 = _getProxyBalance(token0) - startingBalance0;
        uint256 amount1 = _getProxyBalance(token1) - startingBalance1;

        _decreaseRateLimit(getAggregateWithdrawRateLimitKey(poolId), _normalizedSum(token0, token1, amount0, amount1));
        _decreaseRateLimit(getAssetWithdrawRateLimitKey(poolId, token0), amount0);
        _decreaseRateLimit(getAssetWithdrawRateLimitKey(poolId, token1), amount1);

        emit DualPoolWithdraw(poolId, sharesToBurn, amount0, amount1);
    }

    /// @inheritdoc IDualPoolFacet
    function swap(PoolKey calldata key, address tokenIn, uint128 amountIn, uint128 amountOutMin)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        ( bytes32 poolId, , ) = _requireOnboarded(key);

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        require(tokenIn == token0 || tokenIn == token1, "DualPoolFacet/invalid-tokenIn");

        require(amountIn != 0, "DualPoolFacet/zero-amount-in");

        // NOTE: Rate limit decrease does not account for the net amount of tokenIn actually taken.
        _decreaseRateLimit(getSwapRateLimitKey(poolId, tokenIn), amountIn);

        address tokenOut = tokenIn == token0 ? token1 : token0;

        _requireSwapValue(poolId, token0, token1, tokenIn == token0, amountIn, amountOutMin);

        uint128 amountOut = _swap({
            tokenIn  : tokenIn,
            tokenOut : tokenOut,
            amountIn : amountIn,
            callData : _getSwapCallData(key, tokenIn, amountIn, amountOutMin)
        });

        require(amountOut >= amountOutMin, "DualPoolFacet/amountOutMin-not-met");

        emit DualPoolSwap(poolId, tokenIn, tokenOut, amountIn, amountOut);
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

    /// @inheritdoc IDualPoolFacet
    function getSwapRateLimitKey(bytes32 poolId, address token)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressBytes32Key(_LIMIT_SWAP, token, poolId);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _approveWithPermit2(address token, address spender, uint128 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;

        // Approve the Permit2 contract to spend the amount of token.
        ApproveLib.approve(token, proxy, permit2, amount);

        // Approve the spender to spend the token via Permit2.
        IALMProxy(proxy).doCall(
            permit2,
            abi.encodeCall(
                IPermit2Like.approve,
                (token, spender, uint160(amount), uint48(block.timestamp))
            )
        );
    }

    function _doCall(address target, bytes memory data) internal returns (bytes memory result) {
        return IALMProxy(_getSharedControllerStorage().proxy).doCall(target, data);
    }

    function _swap(address tokenIn, address tokenOut, uint128 amountIn, bytes memory callData)
        internal
        returns (uint128 amountOut)
    {
        _approveWithPermit2(tokenIn, router, amountIn);

        uint256 startingBalance = _getProxyBalance(tokenOut);

        // Perform action.
        _doCall(router, callData);

        // Reset approval of Permit2 in tokenIn.
        _approveWithPermit2(tokenIn, router, 0);

        return uint128(_getProxyBalance(tokenOut) - startingBalance);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _clampedSub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        return a > b ? a - b : 0;
    }

    function _getNormalizedBalance(address token, uint256 balance)
        internal
        view
        returns (uint256 normalizedBalance)
    {
        return balance * 1e18 / (10 ** IERC20Like(token).decimals());
    }

    function _getProxyBalance(address token) internal view returns (uint256 balance) {
        return IERC20Like(token).balanceOf(_getSharedControllerStorage().proxy);
    }

    function _getSwapCallData(PoolKey calldata key, address tokenIn, uint128 amountIn, uint128 amountOutMin)
        internal
        view
        returns (bytes memory callData)
    {
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey          : key,
                zeroForOne       : tokenIn == Currency.unwrap(key.currency0),
                amountIn         : amountIn,
                amountOutMinimum : amountOutMin,
                hookData         : bytes("")
            })
        );

        params[1] = abi.encode(tokenIn, amountIn);
        params[2] = abi.encode(
            tokenIn == Currency.unwrap(key.currency0) ? key.currency1 : key.currency0,
            amountOutMin
        );

        // Combine actions and params into inputs.
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(actions, params);

        return abi.encodeCall(
            IUniversalRouterLike.execute,
            (abi.encodePacked(uint8(_V4_SWAP)), inputs, block.timestamp)
        );
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

    /// @notice Governance value floor over the allocator's amountOutMin. Both sides are priced
    ///         through the pool's ratio, so the floor constrains value rather than token counts;
    ///         each amount is placed on its own currency's leg, which is what makes the two sides
    ///         comparable when the pair is not 1:1.
    function _requireSwapValue(
        bytes32 poolId,
        address token0,
        address token1,
        bool    zeroForOne,
        uint128 amountIn,
        uint128 amountOutMin
    )
        internal
        view
    {
        FacetStorage storage $ = _getFacetStorage();

        uint256 priceRatio = $.priceRatios[poolId];

        uint256 valueIn = zeroForOne
            ? _pairValue(token0, token1, amountIn, 0, priceRatio)
            : _pairValue(token0, token1, 0, amountIn, priceRatio);

        uint256 valueOutMin = zeroForOne
            ? _pairValue(token0, token1, 0, amountOutMin, priceRatio)
            : _pairValue(token0, token1, amountOutMin, 0, priceRatio);

        require(
            valueOutMin * 1e18 >= valueIn * $.maxSlippages[poolId],
            "DualPoolFacet/amountOutMin-too-low"
        );
    }

    function _requireHookPool(PoolKey calldata key) internal view returns (bytes32 poolId) {
        require(address(key.hooks) == hook, "DualPoolFacet/invalid-hook");

        poolId = keccak256(abi.encode(key));
    }

    /// @notice Validates that a pool is onboarded for allocator operations, which requires both
    ///         halves of the value floor to be configured: a max slippage and a currency price
    ///         ratio. Requiring the ratio is what stops a pool from being onboarded with floors
    ///         that silently price its two currencies at parity.
    /// @dev    The allocator entry points destructure only poolId and let the _require*Value
    ///         helpers re-read the config from storage, which keeps their stacks within the
    ///         compiler's limit.
    function _requireOnboarded(PoolKey calldata key)
        internal
        view
        returns (bytes32 poolId, uint256 maxSlippage, uint256 priceRatio)
    {
        poolId = _requireHookPool(key);

        FacetStorage storage $ = _getFacetStorage();

        maxSlippage = $.maxSlippages[poolId];
        priceRatio  = $.priceRatios[poolId];

        require(maxSlippage != 0, "DualPoolFacet/max-slippage-not-set");
        require(priceRatio  != 0, "DualPoolFacet/price-ratio-not-set");
    }

}
