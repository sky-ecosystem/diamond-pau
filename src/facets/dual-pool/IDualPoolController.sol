// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { PoolKey } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

interface IDualPoolController {

    function dualPool_VERSION() external pure returns (string memory);

    function dualPool_deposit(
        PoolKey calldata key,
        uint256          sharesToMint,
        uint128          amount0Max,
        uint128          amount1Max
    ) external;

    function dualPool_setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    function dualPool_withdraw(
        PoolKey calldata key,
        uint256          sharesToBurn,
        uint128          amount0Min,
        uint128          amount1Min
    ) external;

    function dualPool_getAggregateDepositRateLimitKey(bytes32 poolId)
        external
        pure
        returns (bytes32 key);

    function dualPool_getAggregateWithdrawRateLimitKey(bytes32 poolId)
        external
        pure
        returns (bytes32 key);

    function dualPool_getAssetDepositRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function dualPool_getAssetWithdrawRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    function dualPool_getMaxSlippage(bytes32 poolId) external view returns (uint256 maxSlippage);

}
