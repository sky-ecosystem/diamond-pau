// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IMerklFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when an operator is toggled.
     * @param operator Operator address.
     */
    event MerklToggleOperator(address indexed operator);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Toggles a operator.
     * @param operator Operator address.
     */
    function toggleOperator(address operator) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Merkl distributor address.
     * @return address Merkl distributor address.
     */
    function distributor() external view returns (address);

}
