// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IUniswapV3Facet } from "./IUniswapV3Facet.sol";

interface IUniswapV3Controller {

    function uniswapV3_VERSION() external pure returns (string memory);

    function uniswapV3_MAX_TICK_DELTA() external pure returns (uint24);

    function uniswapV3_MIN_TICK() external pure returns (int24);

    function uniswapV3_MAX_TICK() external pure returns (int24);

    function uniswapV3_positionManager() external view returns (address);

    function uniswapV3_router() external view returns (address);

    function uniswapV3_setMaxSlippage(address pool, uint256 maxSlippage) external;

    function uniswapV3_setMaxTickDelta(address pool, uint24 maxTickDelta) external;

    function uniswapV3_setLiquidityLowerTickBound(address pool, int24 lowerTickBound) external;

    function uniswapV3_setLiquidityUpperTickBound(address pool, int24 upperTickBound) external;

    function uniswapV3_setTWAPSecondsAgo(address pool, uint32 twapSecondsAgo) external;

    function uniswapV3_swap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24  tickDelta
    )
        external
        returns (uint256 amountOut);

    function uniswapV3_addLiquidity(
        address                               pool,
        uint256                               tokenId,
        IUniswapV3Facet.Ticks        calldata ticks,
        IUniswapV3Facet.TokenAmounts calldata target,
        IUniswapV3Facet.TokenAmounts calldata min,
        uint256                               deadline
    )
        external
        returns (uint256, uint128, IUniswapV3Facet.TokenAmounts memory);

    function uniswapV3_removeLiquidity(
        address                               pool,
        uint256                               tokenId,
        uint128                               liquidity,
        IUniswapV3Facet.TokenAmounts calldata min,
        uint256                               deadline
    )
        external
        returns (IUniswapV3Facet.TokenAmounts memory);

    function uniswapV3_getAggregateDepositRateLimitKey(address pool)
        external
        pure
        returns (bytes32 key);

    function uniswapV3_getAssetDepositRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV3_getLiquidityTickBounds(address pool)
        external
        view
        returns (int24 lower, int24 upper);

    function uniswapV3_getMaxSlippage(address pool) external view returns (uint256);

    function uniswapV3_getMaxTickDelta(address pool) external view returns (uint24);

    function uniswapV3_getSwapRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV3_getTWAPSecondsAgo(address pool) external view returns (uint32);

    function uniswapV3_getAggregateWithdrawRateLimitKey(address pool)
        external
        pure
        returns (bytes32 key);

    function uniswapV3_getAssetWithdrawRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

}
