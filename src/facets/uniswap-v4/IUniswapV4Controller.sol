// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PoolKey } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

interface IUniswapV4Controller {

    function uniswapV4_VERSION() external pure returns (string memory);

    function uniswapV4_permit2() external view returns (address);

    function uniswapV4_positionManager() external view returns (address);

    function uniswapV4_router() external view returns (address);

    function uniswapV4_setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function uniswapV4_setTickLimits(
        bytes32 poolId,
        int24   tickLowerMin,
        int24   tickUpperMax,
        uint24  maxTickSpacing
    )
        external;

    function uniswapV4_mintPosition(
        bytes32 poolId,
        int24   tickLower,
        int24   tickUpper,
        uint128 liquidity,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    function uniswapV4_increasePosition(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityIncrease,
        uint128 amount0Max,
        uint128 amount1Max
    )
        external;

    function uniswapV4_decreasePosition(
        bytes32 poolId,
        uint256 tokenId,
        uint128 liquidityDecrease,
        uint128 amount0Min,
        uint128 amount1Min
    )
        external;

    function uniswapV4_swap(
        PoolKey calldata poolKey,
        address          tokenIn,
        uint128          amountIn,
        uint128          amountOutMin
    )
        external;

    function uniswapV4_getAggregateDepositRateLimitKey(bytes32 poolId)
        external
        pure
        returns (bytes32 key);

    function uniswapV4_getAssetDepositRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV4_getMaxSlippage(bytes32 poolId) external view returns (uint256);

    function uniswapV4_getSwapRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function uniswapV4_getTickLimits(bytes32 poolId)
        external
        view
        returns (int24 tickLowerMin, int24 tickUpperMax, uint24 maxTickSpacing);

    function uniswapV4_getAggregateWithdrawRateLimitKey(bytes32 poolId)
        external
        pure
        returns (bytes32 key);

    function uniswapV4_getAssetWithdrawRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

}
