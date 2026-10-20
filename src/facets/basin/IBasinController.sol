// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IBasinController {

    function basin_VERSION() external pure returns (string memory);

    function basin_deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    function basin_withdraw(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 minConversionRate
    )
        external
        returns (uint256 assetsWithdrawn);

    function basin_getDepositRateLimitKey(address basin, address asset)
        external
        pure
        returns (bytes32 key);

    function basin_getWithdrawRateLimitKey(address basin, address asset)
        external
        pure
        returns (bytes32 key);

}
