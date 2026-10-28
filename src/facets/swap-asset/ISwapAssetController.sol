// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ISwapAssetController {

    function swapAsset_VERSION() external pure returns (string memory);

    function swapAsset_initiateSwap(
        address counterpartyController,
        address assetOut,
        address assetIn,
        uint256 amountOut
    )
        external;

    function swapAsset_completeSwap(address assetOut, address assetIn, uint256 amountOut) external;

    function swapAsset_getInitiateSwapRateLimitKey(
        address assetOut,
        address counterpartyProxy,
        address assetIn
    )
        external
        pure
        returns (bytes32 key);

    function swapAsset_getCompleteSwapRateLimitKey(
        address assetOut,
        address counterpartyProxy,
        address assetIn
    )
        external
        pure
        returns (bytes32 key);

}
