// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IPSM3Facet
 * @notice PAU facet for depositing into and withdrawing from the Spark PSM3 (multi-asset Peg
 *         Stability Module).
 */
interface IPSM3Facet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an asset is deposited into the PSM.
     * @param  asset  Address of the deposited asset token.
     * @param  amount Amount of asset deposited (native token decimals).
     * @param  shares Amount of PSM shares received.
     */
    event PSM3Deposit(address indexed asset, uint256 amount, uint256 shares);

    /**
     * @notice Emitted when the deposit rate limit for an asset is updated.
     * @param  key   Derived key of the rate limit.
     * @param  asset Address of the asset.
     */
    event PSM3DepositRateLimitSet(bytes32 indexed key, address indexed asset);

    /**
     * @notice Emitted when an asset is withdrawn from the PSM.
     * @param  asset           Address of the withdrawn asset token.
     * @param  assetsWithdrawn Actual amount of asset withdrawn (native decimals).
     * @param  sharesBurned    Amount of PSM shares burned.
     */
    event PSM3Withdraw(address indexed asset, uint256 assetsWithdrawn, uint256 sharesBurned);

    /**
     * @notice Emitted when the withdraw rate limit for an asset is updated.
     * @param  key   Derived key of the rate limit.
     * @param  asset Address of the asset.
     */
    event PSM3WithdrawRateLimitSet(bytes32 indexed key, address indexed asset);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposits an asset into the PSM.
     * @param  asset  Address of the asset to deposit.
     * @param  amount Amount of asset to deposit (native token decimals).
     * @return shares Amount of PSM shares received.
     */
    function deposit(address asset, uint256 amount) external returns (uint256 shares);

    /**
     * @notice Sets the deposit rate limit for an asset.
     * @param  asset      Address of the asset.
     * @param  maxAmount  Maximum amount of the rate limit.
     * @param  slope      Slope of the rate limit.
     * @param  lastAmount Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the withdraw rate limit for an asset.
     * @param  asset      Address of the asset.
     * @param  maxAmount  Maximum amount of the rate limit.
     * @param  slope      Slope of the rate limit.
     * @param  lastAmount Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address asset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Withdraws an asset from the PSM up to `maxAmount`.
     * @param  asset           Address of the asset to withdraw.
     * @param  maxAmount       Maximum amount of asset to withdraw (native decimals).
     * @return assetsWithdrawn Actual amount of asset withdrawn.
     */
    function withdraw(address asset, uint256 maxAmount) external returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /// @notice Address of the PSM3 contract (immutable).
    function psm() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured deposit rate limit for an asset.
     * @param  asset Address of the asset.
     * @return data  Rate limit data.
     */
    function getDepositRateLimit(address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the configured withdraw rate limit for an asset.
     * @param  asset Address of the asset.
     * @return data  Rate limit data.
     */
    function getWithdrawRateLimit(address asset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
