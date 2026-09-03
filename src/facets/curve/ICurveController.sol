// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ICurveController {

    function curve_VERSION() external pure returns (string memory);

    function curve_setMaxSlippage(address pool, uint256 maxSlippage) external;

    function curve_swap(
        address pool,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    function curve_addLiquidity(address pool, uint256[] calldata inputAmounts, uint256 minShares)
        external
        returns (uint256 shares);

    function curve_removeLiquidity(
        address            pool,
        uint256            shares,
        uint256[] calldata minWithdrawAmounts
    )
        external
        returns (uint256[] memory withdrawnAmounts);

    function curve_getAggregateDepositRateLimitKey(address pool)
        external
        pure
        returns (bytes32 key);

    function curve_getAssetDepositRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function curve_getMaxSlippage(address pool) external view returns (uint256 maxSlippage);

    function curve_getSwapRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

    function curve_getAggregateWithdrawRateLimitKey(address pool)
        external
        pure
        returns (bytes32 key);

    function curve_getAssetWithdrawRateLimitKey(address pool, address token)
        external
        pure
        returns (bytes32 key);

}
