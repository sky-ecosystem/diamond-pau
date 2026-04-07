// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAccessControlEnumerable
} from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IPAUFactory is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event PAUDeployed(
        address indexed admin,
        address indexed controller,
        address         accessControls,
        address         almProxy,
        address         rateLimits
    );

    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    error ZeroRegistry();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function deploy(address admin) external returns (address controller);

    function setRegistry(address newRegistry) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function registry() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

}
