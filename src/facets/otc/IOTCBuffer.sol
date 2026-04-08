// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAccessControlEnumerable
} from "../../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IOTCBuffer is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Approves `allowance` of `asset`.
     * @param asset     Asset address.
     * @param allowance Amount of allowance.
     */
    function approve(address asset, uint256 allowance) external;

    /**
     * @dev   Initializes the OTC buffer.
     * @param admin    Admin address.
     * @param almProxy ALM proxy address.
     */
    function initialize(address admin, address almProxy) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    ALM proxy address.
     * @return address ALM proxy address.
     */
    function almProxy() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Supports the interface.
     * @param  interfaceId Interface ID.
     * @return bool        True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

}
