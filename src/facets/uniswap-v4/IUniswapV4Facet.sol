// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IUniswapV4Facet
 * @notice DiamondPAU facet for interacting with Uniswap V4 pools. Supports
 *         minting, increasing, and decreasing concentrated liquidity positions,
 *         and exact-input token swaps via the Universal Router.
 */
interface IUniswapV4Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct TickLimits {
        int24  tickLowerMin;
        int24  tickUpperMax;
        uint24 maxTickSpacing;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when a position's liquidity is decreased.
     * @param poolId            Uniswap V4 pool identifier.
     * @param tokenId           NFT token ID of the position.
     * @param liquidityDecrease Amount of liquidity removed.
     * @param amount0           Amount of token0 received.
     * @param amount1           Amount of token1 received.
     */
    event UniswapV4DecreasePosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        uint128         liquidityDecrease,
        uint128         amount0,
        uint128         amount1
    );

    /**
     * @dev   Emitted when a position's liquidity is increased.
     * @param poolId            Uniswap V4 pool identifier.
     * @param tokenId           NFT token ID of the position.
     * @param liquidityIncrease Amount of liquidity added.
     * @param amount0           Amount of token0 deposited.
     * @param amount1           Amount of token1 deposited.
     */
    event UniswapV4IncreasePosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        uint128         liquidityIncrease,
        uint128         amount0,
        uint128         amount1
    );

    /**
     * @dev   Emitted when the max slippage for a pool is updated.
     * @param poolId      Uniswap V4 pool identifier.
     * @param maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event UniswapV4MaxSlippageSet(bytes32 indexed poolId, uint256 maxSlippage);

    /**
     * @dev   Emitted when a new liquidity position is minted.
     * @param poolId    Uniswap V4 pool identifier.
     * @param tokenId   NFT token ID of the new position.
     * @param tickLower Lower tick of the position range.
     * @param tickUpper Upper tick of the position range.
     * @param liquidity Amount of liquidity minted.
     * @param amount0   Amount of token0 deposited.
     * @param amount1   Amount of token1 deposited.
     */
    event UniswapV4MintPosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        int24           tickLower,
        int24           tickUpper,
        uint128         liquidity,
        uint128         amount0,
        uint128         amount1
    );

    /**
     * @dev   Emitted when a token swap is executed.
     * @param poolId    Uniswap V4 pool identifier.
     * @param tokenIn   Address of the input token.
     * @param tokenOut  Address of the output token.
     * @param amountIn  Amount of input tokens spent.
     * @param amountOut Amount of output tokens received.
     */
    event UniswapV4Swap(
        bytes32 indexed poolId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint128         amountIn,
        uint128         amountOut
    );

    /**
     * @dev   Emitted when tick limits for a pool are updated.
     * @param poolId         Uniswap V4 pool identifier.
     * @param tickLowerMin   Minimum allowed lower tick for positions.
     * @param tickUpperMax   Maximum allowed upper tick for positions.
     * @param maxTickSpacing Maximum allowed tick spacing between lower and upper.
     */
    event UniswapV4TickLimitsSet(
        bytes32 indexed poolId,
        int24           tickLowerMin,
        int24           tickUpperMax,
        uint24          maxTickSpacing
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Decreases the liquidity of an existing position.
     * @param poolId            Uniswap V4 pool identifier.
     * @param tokenId           NFT token ID of the position.
     * @param liquidityDecrease Amount of liquidity to remove.
     * @param amount0Min        Minimum amount of token0 to receive.
     * @param amount1Min        Minimum amount of token1 to receive.
     */
    function decreasePosition(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityDecrease,
        uint128 amount0Min,
        uint128 amount1Min
    )
        external;

    /**
     * @dev   Increases the liquidity of an existing position.
     * @param poolId            Uniswap V4 pool identifier.
     * @param tokenId           NFT token ID of the position.
     * @param liquidityIncrease Amount of liquidity to add.
     * @param amount0Max        Maximum amount of token0 to spend.
     * @param amount1Max        Maximum amount of token1 to spend.
     */
    function increasePosition(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityIncrease,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    /**
     * @dev   Mints a new liquidity position in a Uniswap V4 pool.
     * @param poolId     Uniswap V4 pool identifier.
     * @param tickLower  Lower tick of the position range.
     * @param tickUpper  Upper tick of the position range.
     * @param liquidity  Amount of liquidity to mint.
     * @param amount0Max Maximum amount of token0 to spend.
     * @param amount1Max Maximum amount of token1 to spend.
     */
    function mintPosition(
        bytes32 poolId,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    /**
     * @dev   Sets the max slippage for a Uniswap V4 pool.
     * @param poolId      Uniswap V4 pool identifier.
     * @param maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    /**
     * @dev   Sets the tick limits for liquidity positions on a pool.
     * @param poolId         Uniswap V4 pool identifier.
     * @param tickLowerMin   Minimum allowed lower tick.
     * @param tickUpperMax   Maximum allowed upper tick.
     * @param maxTickSpacing Maximum allowed tick spacing between bounds.
     */
    function setTickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
    )
        external;

    /**
     * @dev   Swaps tokens via the Uniswap V4 Universal Router (exact input).
     * @param poolId       Uniswap V4 pool identifier.
     * @param tokenIn      Address of the input token.
     * @param amountIn     Amount of input tokens to swap.
     * @param amountOutMin Minimum output tokens to receive.
     */
    function swap(bytes32 poolId, address tokenIn, uint128 amountIn, uint128 amountOutMin) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Uniswap V4 deposit (mint/increase) operations,
     *         combined with the pool ID to form per-pool keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for Uniswap V4 swap operations, combined with the
     *         pool ID to form per-pool keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for Uniswap V4 withdraw (decrease) operations,
     *         combined with the pool ID to form per-pool keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Address of the Permit2 contract used for token approvals (immutable).
     * @return address The Permit2 contract address.
     */
    function permit2() external view returns (address);

    /**
     * @dev    Address of the Uniswap V4 PositionManager contract (immutable).
     * @return address The position manager contract address.
     */
    function positionManager() external view returns (address);

    /**
     * @dev    Address of the Uniswap V4 Universal Router contract (immutable).
     * @return address The router contract address.
     */
    function router() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the configured max slippage for a Uniswap V4 pool.
     * @param  poolId  Uniswap V4 pool identifier.
     * @return uint256 Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(bytes32 poolId) external view returns (uint256);

    /**
     * @dev    Returns the configured tick limits for a Uniswap V4 pool.
     * @param  poolId         Uniswap V4 pool identifier.
     * @return tickLowerMin   Minimum allowed lower tick.
     * @return tickUpperMax   Maximum allowed upper tick.
     * @return maxTickSpacing Maximum allowed tick spacing.
     */
    function getTickLimits(bytes32 poolId)
        external
        view
        returns (int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing);

}
