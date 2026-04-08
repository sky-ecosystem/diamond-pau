// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  ISparkVaultFacet
 * @notice DiamondPAU facet for taking (drawing) assets from a Spark vault.
 */
interface ISparkVaultFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when assets are taken from a Spark vault.
     * @param sparkVault  Address of the Spark vault.
     * @param assetAmount Amount of assets taken.
     */
    event SparkVaultTake(address indexed sparkVault, uint256 assetAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Takes (draws) assets from a Spark vault to the proxy.
     * @param sparkVault  Address of the Spark vault.
     * @param assetAmount Amount of assets to take.
     */
    function take(address sparkVault, uint256 assetAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Spark vault take operations, combined with the
     *         vault address to form per-vault keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_TAKE() external pure returns (bytes32);

}