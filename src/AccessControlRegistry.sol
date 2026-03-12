// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControlEnumerable } from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";
import { ReentrancyGuard }         from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IAccessControlRegistry } from "./interfaces/IAccessControlRegistry.sol";

contract AccessControlRegistry is IAccessControlRegistry, ReentrancyGuard, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER");

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**********************************************************************************************/
    /*** Interactive functions                                                                  ***/
    /**********************************************************************************************/

    function removeRelayer(address relayer) external nonReentrant onlyRole(FREEZER_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
        emit IAccessControlRegistry.RelayerRemoved(relayer);
    }

    /**********************************************************************************************/
    /*** View/Pure functions                                                                    ***/
    /**********************************************************************************************/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IAccessControlRegistry, AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(IAccessControlRegistry).interfaceId || super.supportsInterface(interfaceId);
    }
}
