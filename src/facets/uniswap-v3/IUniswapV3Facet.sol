// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IUniswapV3Facet
 * @notice DiamondPAU facet for interacting with Uniswap V3 pools. Supports
 *         adding/removing concentrated liquidity positions, and exact-input
 *         token swaps via the Uniswap V3 SwapRouter.
 */
interface IUniswapV3Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct Ticks {
        int24 lower;
        int24 upper;
    }

    struct TokenAmounts {
        uint256 amount0;
        uint256 amount1;
    }

    struct PoolParams {
        uint24 swapMaxTickDelta;
        Ticks  liquidityTickBounds;
        uint32 twapSecondsAgo;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when liquidity is added to a Uniswap V3 position.
     * @param pool      Address of the Uniswap V3 pool.
     * @param tokenId   NFT token ID of the liquidity position (0 for new mints).
     * @param tickLower Lower tick of the position range.
     * @param tickUpper Upper tick of the position range.
     * @param liquidity Amount of liquidity added.
     * @param amount0   Amount of token0 deposited.
     * @param amount1   Amount of token1 deposited.
     */
    event UniswapV3AddLiquidity(
        address indexed pool,
        uint256 indexed tokenId,
        int24           tickLower,
        int24           tickUpper,
        uint128         liquidity,
        uint256         amount0,
        uint256         amount1
    );

    /**
     * @dev   Emitted when the max slippage for a pool is updated.
     * @param pool        Address of the Uniswap V3 pool.
     * @param maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event UniswapV3MaxSlippageSet(address indexed pool, uint256 maxSlippage);

    /**
     * @dev   Emitted when the max tick delta for swaps on a pool is updated.
     * @param pool         Address of the Uniswap V3 pool.
     * @param maxTickDelta New max allowed tick deviation from TWAP for swaps.
     */
    event UniswapV3MaxTickDeltaSet(address indexed pool, uint24 maxTickDelta);

    /**
     * @dev   Emitted when liquidity is removed from a Uniswap V3 position.
     * @param pool      Address of the Uniswap V3 pool.
     * @param tokenId   NFT token ID of the liquidity position.
     * @param liquidity Amount of liquidity removed.
     * @param amount0   Amount of token0 received.
     * @param amount1   Amount of token1 received.
     */
    event UniswapV3RemoveLiquidity(
        address indexed pool,
        uint256 indexed tokenId,
        uint128         liquidity,
        uint256         amount0,
        uint256         amount1
    );

    /**
     * @dev   Emitted when a token swap is executed on a Uniswap V3 pool.
     * @param pool          Address of the Uniswap V3 pool.
     * @param tokenIn       Address of the input token.
     * @param amountInSpent Amount of input tokens spent.
     * @param amountOut     Amount of output tokens received.
     */
    event UniswapV3Swap(
        address indexed pool,
        address indexed tokenIn,
        uint256         amountInSpent,
        uint256         amountOut
    );

    /**
     * @dev   Emitted when the lower tick bound for a pool is updated.
     * @param pool      Address of the Uniswap V3 pool.
     * @param lowerTick New lower tick bound for liquidity positions.
     */
    event UniswapV3LowerTickUpdated(address indexed pool, int24 lowerTick);

    /**
     * @dev   Emitted when the TWAP lookback period for a pool is updated.
     * @param pool           Address of the Uniswap V3 pool.
     * @param twapSecondsAgo New TWAP lookback duration in seconds.
     */
    event UniswapV3TWAPSecondsAgoUpdated(address indexed pool, uint32 twapSecondsAgo);

    /**
     * @dev   Emitted when the upper tick bound for a pool is updated.
     * @param pool      Address of the Uniswap V3 pool.
     * @param upperTick New upper tick bound for liquidity positions.
     */
    event UniswapV3UpperTickUpdated(address indexed pool, int24 upperTick);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Adds liquidity to a Uniswap V3 position. If tokenId is 0, mints
     *        a new position; otherwise increases an existing one.
     * @param pool     Address of the Uniswap V3 pool.
     * @param tokenId  NFT token ID (0 to create a new position).
     * @param ticks    Lower and upper tick bounds for the position.
     * @param target   Target amounts of token0 and token1 to deposit.
     * @param min      Minimum amounts of token0 and token1 to deposit.
     * @param deadline Unix timestamp deadline for the transaction.
     */
    function addLiquidity(
        address               pool,
        uint256               tokenId,
        Ticks        calldata ticks,
        TokenAmounts calldata target,
        TokenAmounts calldata min,
        uint256               deadline
    )
        external
        returns (uint256 tokenId_, uint128 liquidity_, TokenAmounts memory amounts_);

    /**
     * @dev   Removes liquidity from a Uniswap V3 position and collects tokens.
     * @param pool      Address of the Uniswap V3 pool.
     * @param tokenId   NFT token ID of the position.
     * @param liquidity Amount of liquidity to remove.
     * @param min       Minimum amounts of token0 and token1 to receive.
     * @param deadline  Unix timestamp deadline for the transaction.
     */
    function removeLiquidity(
        address               pool,
        uint256               tokenId,
        uint128               liquidity,
        TokenAmounts calldata min,
        uint256               deadline
    )
        external
        returns (TokenAmounts memory amounts);

    /**
     * @dev   Sets the max slippage for a Uniswap V3 pool.
     * @param pool        Address of the Uniswap V3 pool.
     * @param maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address pool, uint256 maxSlippage) external;

    /**
     * @dev   Sets the max tick delta allowed for swaps on a pool. Limits how
     *        far the current tick can deviate from the TWAP tick.
     * @param pool         Address of the Uniswap V3 pool.
     * @param maxTickDelta Max allowed tick deviation from TWAP.
     */
    function setMaxTickDelta(address pool, uint24 maxTickDelta) external;

    /**
     * @dev   Sets the lower tick bound for liquidity positions on a pool.
     * @param pool           Address of the Uniswap V3 pool.
     * @param lowerTickBound Minimum lower tick for positions.
     */
    function setLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;

    /**
     * @dev   Sets the upper tick bound for liquidity positions on a pool.
     * @param pool           Address of the Uniswap V3 pool.
     * @param upperTickBound Maximum upper tick for positions.
     */
    function setLiquidityUpperTickBound(address pool, int24 upperTickBound) external;

    /**
     * @dev   Sets the TWAP lookback period for a pool. Used to compute the
     *        time-weighted average tick for swap validation.
     * @param pool           Address of the Uniswap V3 pool.
     * @param twapSecondsAgo TWAP lookback duration in seconds.
     */
    function setTWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;

    /**
     * @dev    Swaps tokens via the Uniswap V3 SwapRouter (exact input single).
     * @param  pool         Address of the Uniswap V3 pool.
     * @param  tokenIn      Address of the input token.
     * @param  amountIn     Amount of input tokens to swap.
     * @param  minAmountOut Minimum output tokens to receive.
     * @param  tickDelta    Max tick deviation from TWAP for this swap.
     * @return amountOut    Actual amount of output tokens received.
     */
    function swap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24  tickDelta
    )
        external
        returns (uint256 amountOut);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Uniswap V3 deposit (add liquidity) operations,
     *         combined with the pool's token pair for per-pair keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for Uniswap V3 swap operations, combined with the
     *         pool's token pair for per-pair keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for Uniswap V3 withdraw (remove liquidity) operations,
     *         combined with the pool's token pair for per-pair keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Upper bound for the max tick delta admin parameter.
     * @return uint24 The maximum configurable tick delta.
     */
    function MAX_TICK_DELTA() external pure returns (uint24);

    /**
     * @dev    Uniswap V3 minimum tick value (from TickMath).
     * @return int24 The minimum tick.
     */
    function MIN_TICK() external pure returns (int24);

    /**
     * @dev    Uniswap V3 maximum tick value (from TickMath).
     * @return int24 The maximum tick.
     */
    function MAX_TICK() external pure returns (int24);

    /**
     * @dev    Address of the Uniswap V3 NonfungiblePositionManager (immutable).
     * @return address The position manager contract address.
     */
    function positionManager() external view returns (address);

    /**
     * @dev    Address of the Uniswap V3 SwapRouter (immutable).
     * @return address The router contract address.
     */
    function router() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the configured max slippage for a Uniswap V3 pool.
     * @param  pool    Address of the pool.
     * @return uint256 Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address pool) external view returns (uint256);

    /**
     * @dev    Returns the configured max tick delta for swaps on a pool.
     * @param  pool   Address of the pool.
     * @return uint24 Max tick delta. Zero means not set.
     */
    function getMaxTickDelta(address pool) external view returns (uint24);

    /**
     * @dev    Returns the configured tick bounds for liquidity positions.
     * @param  pool  Address of the pool.
     * @return lower Minimum lower tick bound.
     * @return upper Maximum upper tick bound.
     */
    function getLiquidityTickBounds(address pool) external view returns (int24 lower, int24 upper);

    /**
     * @dev    Returns the configured TWAP lookback period for a pool.
     * @param  pool   Address of the pool.
     * @return uint32 TWAP lookback duration in seconds. Zero means not set.
     */
    function getTWAPSecondsAgo(address pool) external view returns (uint32);

}
