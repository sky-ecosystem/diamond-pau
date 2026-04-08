// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

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
     * @dev   Event emitted when liquidity is added.
     * @param pool      Pool address.
     * @param tokenId   Token ID.
     * @param tickLower Lower tick.
     * @param tickUpper Upper tick.
     * @param liquidity Liquidity added.
     * @param amount0   Amount of token0.
     * @param amount1   Amount of token1.
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
     * @dev   Event emitted when a max slippage is set.
     * @param pool        Pool address.
     * @param maxSlippage Max slippage allowed.
     */
    event UniswapV3MaxSlippageSet(address indexed pool, uint256 maxSlippage);

    /**
     * @dev   Event emitted when a max tick delta is set.
     * @param pool         Pool address.
     * @param maxTickDelta Max tick delta.
     */
    event UniswapV3MaxTickDeltaSet(address indexed pool, uint24 maxTickDelta);

    /**
     * @dev   Event emitted when liquidity is removed.
     * @param pool      Pool address.
     * @param tokenId   Token ID.
     * @param liquidity Liquidity removed.
     * @param amount0   Amount of token0.
     * @param amount1   Amount of token1.
     */
    event UniswapV3RemoveLiquidity(
        address indexed pool,
        uint256 indexed tokenId,
        uint128         liquidity,
        uint256         amount0,
        uint256         amount1
    );

    /**
     * @dev   Event emitted when a swap is executed.
     * @param pool          Pool address.
     * @param tokenIn       Token in address.
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
     * @dev   Event emitted when a lower tick is updated.
     * @param pool      Pool address.
     * @param lowerTick Lower tick.
     */
    event UniswapV3LowerTickUpdated(address indexed pool, int24 lowerTick);

    /**
     * @dev   Event emitted when a TWAP seconds ago is updated.
     * @param pool           Pool address.
     * @param twapSecondsAgo TWAP seconds ago.
     */
    event UniswapV3TWAPSecondsAgoUpdated(address indexed pool, uint32 twapSecondsAgo);

    /**
     * @dev   Event emitted when an upper tick is updated.
     * @param pool          Pool address.
     * @param upperTick     Upper tick.
     */
    event UniswapV3UpperTickUpdated(address indexed pool, int24 upperTick);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Adds liquidity to a pool.
     * @param pool     Pool address.
     * @param tokenId  Token ID.
     * @param ticks    Ticks.
     * @param target   Target amounts.
     * @param min      Minimum amounts.
     * @param deadline Deadline.
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
     * @dev   Removes liquidity from a pool.
     * @param pool      Pool address.
     * @param tokenId   Token ID.
     * @param liquidity Liquidity.
     * @param min       Minimum amounts.
     * @param deadline  Deadline.
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
     * @dev   Sets a max slippage.
     * @param pool        Pool address.
     * @param maxSlippage Max slippage allowed.
     */
    function setMaxSlippage(address pool, uint256 maxSlippage) external;

    /**
     * @dev   Sets a max tick delta.
     * @param pool          Pool address.
     * @param maxTickDelta  Max tick delta.
     */
    function setMaxTickDelta(address pool, uint24 maxTickDelta) external;

    /**
     * @dev   Sets a lower tick bound.
     * @param pool           Pool address.
     * @param lowerTickBound Lower tick bound.
     */
    function setLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;

    /**
     * @dev   Sets an upper tick bound.
     * @param pool           Pool address.
     * @param upperTickBound Upper tick bound.
     */
    function setLiquidityUpperTickBound(address pool, int24 upperTickBound) external;

    /**
     * @dev   Sets a TWAP seconds ago.
     * @param pool           Pool address.
     * @param twapSecondsAgo TWAP seconds ago.
     */
    function setTWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;

    /**
     * @dev   Swaps tokens in a pool.
     * @param pool         Pool address.
     * @param tokenIn      Token in.
     * @param amountIn     Amount in.
     * @param minAmountOut Minimum amount out.
     * @param tickDelta    Tick delta.
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
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for swap operations.
     * @return bytes32 Key for swap limit.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**
     * @dev    Limit for withdraw operations.
     * @return bytes32 Key for withdraw limit.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Max tick delta.
     * @return uint24 Max tick delta.
     */
    function MAX_TICK_DELTA() external pure returns (uint24);

    /**
     * @dev    Minimum tick.
     * @return int24 Minimum tick.
     */
    function MIN_TICK() external pure returns (int24);

    /**
     * @dev    Maximum tick.
     * @return int24 Maximum tick.
     */
    function MAX_TICK() external pure returns (int24);

    /**
     * @dev    Position manager address.
     * @return address Position manager address.
     */
    function positionManager() external view returns (address);

    /**
     * @dev    Router address.
     * @return address Router address.
     */
    function router() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets a max slippage.
     * @param  pool    Pool address.
     * @return uint256 Max slippage allowed.
     */
    function getMaxSlippage(address pool) external view returns (uint256);

    /**
     * @dev    Gets a max tick delta.
     * @param  pool   Pool address.
     * @return uint24 Max tick delta.
     */
    function getMaxTickDelta(address pool) external view returns (uint24);

    /**
     * @dev    Gets a liquidity tick bounds.
     * @param  pool  Pool address.
     * @return lower Lower tick.
     * @return upper Upper tick.
     */
    function getLiquidityTickBounds(address pool) external view returns (int24 lower, int24 upper);

    /**
     * @dev    Gets a TWAP seconds ago.
     * @param  pool   Pool address.
     * @return uint32 TWAP seconds ago.
     */
    function getTWAPSecondsAgo(address pool) external view returns (uint32);

}
