// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISparkVaultFacet
 * @notice PAU facet for taking (drawing) assets from a Spark vault.
 */
interface ISparkVaultFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when assets are taken from a Spark vault.
     * @param  sparkVault  Address of the Spark vault.
     * @param  assetAmount Amount of assets taken.
     */
    event SparkVaultTake(address indexed sparkVault, uint256 assetAmount);

    /**
     * @notice Emitted when the Spark vault take rate limit is updated.
     * @param  key        Derived key of the rate limit.
     * @param  sparkVault Address of the Spark vault.
     */
    event SparkVaultTakeRateLimitSet(bytes32 indexed key, address indexed sparkVault);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets the Spark vault take rate limit for a vault.
     * @param  sparkVault  Address of the Spark vault.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setTakeRateLimit(
        address sparkVault,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Takes (draws) assets from a Spark vault to the proxy.
     * @param  sparkVault  Address of the Spark vault.
     * @param  assetAmount Amount of assets to take.
     */
    function take(address sparkVault, uint256 assetAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for take operations.
    function LIMIT_TAKE() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured Spark vault take rate limit for a vault.
     * @param  sparkVault Address of the Spark vault.
     * @return data       Rate limit data.
     */
    function getTakeRateLimit(address sparkVault)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
