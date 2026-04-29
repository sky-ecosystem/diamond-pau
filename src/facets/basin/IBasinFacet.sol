// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

interface IBasinFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Event emitted when a deposit is made to a basin.
     * @param  basin  The address of the basin.
     * @param  asset  The address of the asset deposited.
     * @param  amount The amount of the asset deposited.
     * @param  shares The number of shares received.
     */
    event BasinDeposit(
        address indexed basin,
        address indexed asset,
        uint256         amount,
        uint256         shares
    );

    /**
     * @notice Emitted when the basin deposit rate limit is updated.
     * @param  key   Derived key of the rate limit.
     * @param  basin Address of the basin contract.
     * @param  asset Address of the asset.
     */
    event BasinDepositRateLimitSet(
        bytes32 indexed key,
        address indexed basin,
        address indexed asset
    );

    /**
     * @notice Event emitted when a withdrawal is made from a basin.
     * @param  basin           The address of the basin.
     * @param  asset           The address of the asset withdrawn.
     * @param  assetsWithdrawn The amount of the asset withdrawn.
     * @param  sharesBurned    The amount of shares burned.
     */
    event BasinWithdraw(
        address indexed basin,
        address indexed asset,
        uint256         assetsWithdrawn,
        uint256         sharesBurned
    );

    /**
     * @notice Emitted when the basin withdraw rate limit is updated.
     * @param  key   Derived key of the rate limit.
     * @param  basin Address of the basin contract.
     * @param  asset Address of the asset.
     */
    event BasinWithdrawRateLimitSet(
        bytes32 indexed key,
        address indexed basin,
        address indexed asset
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposit `amount` of `asset` into `basin`, return `shares` received.
     * @param  basin        The address of the basin.
     * @param  asset        The address of the asset deposited.
     * @param  amount       The amount of the asset deposited.
     * @param  minSharesOut The minimum number of shares willing to receive.
     * @return shares       The number of shares received.
     */
    function deposit(address basin, address asset, uint256 amount, uint256 minSharesOut)
        external
        returns (uint256 shares);

    /**
     * @notice Sets the deposit rate limit for a basin and asset.
     * @param  basin       Address of the basin contract.
     * @param  asset       Address of the asset.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the withdraw rate limit for a basin and asset.
     * @param  basin       Address of the basin contract.
     * @param  asset       Address of the asset.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address basin,
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Withdraw up to `maxAmount` of `asset` from `basin`, return `assetsWithdrawn`.
     * @param  basin             The address of the basin.
     * @param  asset             The address of the asset withdrawn.
     * @param  maxAmount         The maximum amount of the asset to withdraw.
     * @param  minConversionRate The minimum conversion rate willing to accept.
     * @return assetsWithdrawn   The amount of the asset withdrawn.
     */
    function withdraw(address basin, address asset, uint256 maxAmount, uint256 minConversionRate)
        external
        returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured deposit rate limit for a basin and asset.
     * @param  basin Address of the basin contract.
     * @param  asset Address of the asset.
     * @return data  Rate limit data.
     */
    function getDepositRateLimit(address basin, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the configured withdraw rate limit for a basin and asset.
     * @param  basin Address of the basin contract.
     * @param  asset Address of the asset.
     * @return data  Rate limit data.
     */
    function getWithdrawRateLimit(address basin, address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
