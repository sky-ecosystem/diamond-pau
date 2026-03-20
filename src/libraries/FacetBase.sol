// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ControllerBase } from "../ControllerBase.sol";

import { IAccessControls } from "../interfaces/IAccessControls.sol";
import { IFacetBase }      from "../interfaces/facets/IFacetBase.sol";

abstract contract FacetBase is IFacetBase, ControllerBase {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant RELAYER_ROLE       = keccak256("RELAYER");

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier onlyRole(bytes32 role) {
        address accessControls = _getControllerStorage().accessControls;

        if (!IAccessControls(accessControls).hasRole(role, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, role);
        }

        _;
    }

}
