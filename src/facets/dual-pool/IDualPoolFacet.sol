// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PoolKey } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IDualPoolFacet
 * @notice PAU facet for allocating into DualPoolHook pools. DualPool pools are Uniswap V4 pools
 *         whose liquidity is provisioned just-in-time by the hook from hook-held (and ERC-4626
 *         rehypothecated) reserves; LP entry and exit go through the hook's own share-based
 *         functions rather than the Uniswap V4 PositionManager.
 *
 *         The hook is owned by governance (the Spark Proxy) and its pools are permissionless, so
 *         pool lifecycle and configuration are operated directly by the owner rather than through
 *         this facet, and the ALMProxy enters and exits as a regular LP. Swaps through DualPool
 *         pools go through the UniswapV4 facet's swap, which takes the PoolKey from calldata.
 *
 *         Only 1:1 correlated pairs are onboarded, so the deposit and withdraw value floors weigh
 *         both currencies equally after 18-decimal normalization.
 *
 *         Role model:
 *         - DEFAULT_ADMIN_ROLE (governance): the per-pool max slippage that denominates the
 *           allocator value floors.
 *         - ALLOCATOR_ROLE (assumed compromisable): rate-limited deposit and withdraw, both
 *           value-floored by the governance-set config.
 *
 *         The hook has no poolId to PoolKey registry, so interactive functions take the full
 *         PoolKey from calldata and derive poolId as keccak256(abi.encode(key)). All facet
 *         config and rate limit keys bind to the derived id and key.hooks must match the
 *         facet's immutable hook, so a fabricated key can only reach a disabled configuration.
 */
interface IDualPoolFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted on an allocator deposit.
     * @param  poolId  DualPool pool identifier (keccak256(abi.encode(poolKey))).
     * @param  shares  Shares minted to the ALMProxy.
     * @param  amount0 Measured amount of currency0 spent by the ALMProxy.
     * @param  amount1 Measured amount of currency1 spent by the ALMProxy.
     */
    event DualPoolDeposit(bytes32 indexed poolId, uint256 shares, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when the max slippage for a pool is updated.
     * @param  poolId      DualPool pool identifier.
     * @param  maxSlippage New max slippage in 1e18 precision (1e18 = no slippage). Zero disables.
     */
    event DualPoolMaxSlippageSet(bytes32 indexed poolId, uint256 maxSlippage);

    /**
     * @notice Emitted on an allocator withdrawal.
     * @param  poolId  DualPool pool identifier.
     * @param  shares  Shares burned from the ALMProxy position.
     * @param  amount0 Measured amount of currency0 received by the ALMProxy.
     * @param  amount1 Measured amount of currency1 received by the ALMProxy.
     */
    event DualPoolWithdraw(
        bytes32 indexed poolId,
        uint256         shares,
        uint256         amount0,
        uint256         amount1
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposits into a pool, minting pool shares to the ALMProxy.
     * @param  key          PoolKey of the pool to deposit into.
     * @param  sharesToMint Shares to mint; required amounts follow the pool's current ratio.
     * @param  amount0Max   Maximum amount of currency0 the ALMProxy may spend.
     * @param  amount1Max   Maximum amount of currency1 the ALMProxy may spend.
     */
    function deposit(
        PoolKey calldata key,
        uint256          sharesToMint,
        uint128          amount0Max,
        uint128          amount1Max
    ) external;

    /**
     * @notice Sets the max slippage for a DualPool pool. The value is validated in the governance
     *         spell that schedules the call.
     *
     *         Note that deposit needs a value strictly below 1e18. Its round-trip floor compares
     *         what the shares redeem for against what was paid, and the hook rounds the deposit up
     *         while rounding the redemption down, so the round trip is lossy by design.
     * @param  poolId      DualPool pool identifier (keccak256(abi.encode(poolKey))).
     * @param  maxSlippage Max slippage in 1e18 precision (1e18 = no slippage). Zero disables
     *                     allocator operations.
     */
    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    /**
     * @notice Withdraws from a pool, burning ALMProxy-held pool shares.
     * @param  key          PoolKey of the pool to withdraw from.
     * @param  sharesToBurn Shares to burn.
     * @param  amount0Min   Minimum amount of currency0 the ALMProxy will accept.
     * @param  amount1Min   Minimum amount of currency1 the ALMProxy will accept.
     */
    function withdraw(
        PoolKey calldata key,
        uint256          sharesToBurn,
        uint128          amount0Min,
        uint128          amount1Min
    ) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Address of the governance-owned DualPoolHook deployment this facet allocates into
    ///         (immutable).
    function hook() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the derived aggregate (both-currency, normalized) deposit rate limit key
     *         for a pool.
     * @param  poolId DualPool pool identifier.
     * @return key    Derived rate limit key.
     */
    function getAggregateDepositRateLimitKey(bytes32 poolId) external pure returns (bytes32 key);

    /**
     * @notice Returns the derived aggregate (both-currency, normalized) withdraw rate limit key
     *         for a pool.
     * @param  poolId DualPool pool identifier.
     * @return key    Derived rate limit key.
     */
    function getAggregateWithdrawRateLimitKey(bytes32 poolId) external pure returns (bytes32 key);

    /**
     * @notice Returns the derived deposit rate limit key for a pool and token.
     * @param  poolId DualPool pool identifier.
     * @param  token  Address of the token being deposited.
     * @return key    Derived rate limit key.
     */
    function getAssetDepositRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the derived withdraw rate limit key for a pool and token.
     * @param  poolId DualPool pool identifier.
     * @param  token  Address of the token being withdrawn.
     * @return key    Derived rate limit key.
     */
    function getAssetWithdrawRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the configured max slippage for a DualPool pool.
     * @param  poolId      DualPool pool identifier.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set (disabled).
     */
    function getMaxSlippage(bytes32 poolId) external view returns (uint256 maxSlippage);

}
