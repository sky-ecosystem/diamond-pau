// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ISparkVaultFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event SparkVaultTake(address indexed sparkVault, uint256 assetAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Takes `assetAmount` of `asset` from the Spark vault.
     * @param  sparkVault  Spark vault address.
     * @param  assetAmount Amount of `asset` to take.
     */
    function take(address sparkVault, uint256 assetAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for take operations.
     * @return bytes32 Key for take limit.
     */
    function LIMIT_TAKE() external pure returns (bytes32);

}
