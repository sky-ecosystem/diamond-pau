// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ISwapController {

    function swap_VERSION() external pure returns (string memory);

    function swap_approve(address asset, address counterparty, uint256 allowance) external;

    function swap_setParValue(address asset, uint256 parValue) external;

    function swap_swap(
        address counterparty,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    function swap_getAmountOut(address assetIn, address assetOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    function swap_getAssetParameters(address asset)
        external
        view
        returns (uint256 parValue, uint8 decimals);

    function swap_getSwapRateLimitKey(address assetIn, address assetOut, address counterparty)
        external
        pure
        returns (bytes32 key);

}
