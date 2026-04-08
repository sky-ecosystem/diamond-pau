// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IMerklFacet
 * @notice DiamondPAU facet for toggling operators on the Merkl reward distributor. 
 *         Operators can claim Merkl rewards on behalf of the proxy.
 */
interface IMerklFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when an operator is toggled on the Merkl distributor.
     * @param operator Address of the operator being toggled.
     */
    event MerklToggleOperator(address indexed operator);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Toggles an operator's authorization on the Merkl distributor for the proxy.
     * @param operator Address of the operator to toggle.
     */
    function toggleOperator(address operator) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Address of the Merkl reward distributor contract (immutable).
     * @return address The distributor contract address.
     */
    function distributor() external view returns (address);

}