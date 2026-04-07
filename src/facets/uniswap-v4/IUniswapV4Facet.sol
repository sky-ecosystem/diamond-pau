// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

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

    event UniswapV4DecreasePosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        uint128         liquidityDecrease,
        uint128         amount0,
        uint128         amount1
    );

    event UniswapV4IncreasePosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        uint128         liquidityIncrease,
        uint128         amount0,
        uint128         amount1
    );

    /**
     * @dev   Event emitted when a max slippage is set.
     * @param poolId      Pool ID.
     * @param maxSlippage Max slippage allowed.
     */
    event UniswapV4MaxSlippageSet(bytes32 indexed poolId, uint256 maxSlippage);

    event UniswapV4MintPosition(
        bytes32 indexed poolId,
        uint256 indexed tokenId,
        int24           tickLower,
        int24           tickUpper,
        uint128         liquidity,
        uint128         amount0,
        uint128         amount1
    );

    event UniswapV4Swap(
        bytes32 indexed poolId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint128         amountIn,
        uint128         amountOut
    );

    /**
     * @dev   Event emitted when tick limits are set.
     * @param poolId         Pool ID.
     * @param tickLowerMin   Minimum lower tick.
     * @param tickUpperMax   Maximum upper tick.
     * @param maxTickSpacing Maximum tick spacing.
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
     * @dev   Decreases the liquidity of a position.
     * @param poolId            Pool ID.
     * @param tokenId           Token ID.
     * @param liquidityDecrease Amount of liquidity to decrease.
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
     * @dev   Increases the liquidity of a position.
     * @param poolId            Pool ID.
     * @param tokenId           Token ID.
     * @param liquidityIncrease Amount of liquidity to increase.
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
     * @dev   Mints a position.
     * @param poolId     Pool ID.
     * @param tickLower  Lower tick.
     * @param tickUpper  Upper tick.
     * @param liquidity  Liquidity.
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
     * @dev   Sets a max slippage.
     * @param poolId      Pool ID.
     * @param maxSlippage Max slippage allowed.
     */
    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    /**
     * @dev   Sets tick limits.
     * @param poolId         Pool ID.
     * @param tickLowerMin   Minimum lower tick.
     * @param tickUpperMax   Maximum upper tick.
     * @param maxTickSpacing Maximum tick spacing.
     */
    function setTickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
    )
        external;

    /**
     * @dev   Swaps tokens in a pool.
     * @param poolId       Pool ID.
     * @param tokenIn      Token in.
     * @param amountIn     Amount in.
     * @param amountOutMin Minimum amount out.
     */
    function swap(bytes32 poolId, address tokenIn, uint128 amountIn, uint128 amountOutMin) external;

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
     * @dev    Permit2 contract address.
     * @return address Permit2 contract address.
     */
    function permit2() external view returns (address);

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
     * @param  poolId  Pool ID.
     * @return uint256 Max slippage allowed.
     */
    function getMaxSlippage(bytes32 poolId) external view returns (uint256);

    /**
     * @dev    Gets tick limits.
     * @param  poolId         Pool ID.
     * @return tickLowerMin   Minimum lower tick.
     * @return tickUpperMax   Maximum upper tick.
     * @return maxTickSpacing Maximum tick spacing.
     */
    function getTickLimits(bytes32 poolId)
        external
        view
        returns (int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing);

}
