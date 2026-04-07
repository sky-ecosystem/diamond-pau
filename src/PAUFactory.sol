// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { IAccessControls } from "./interfaces/IAccessControls.sol";

import { AccessControls } from "./AccessControls.sol";
import { ALMProxy }       from "./ALMProxy.sol";
import { Controller }     from "./Controller.sol";
import { RateLimits }     from "./RateLimits.sol";

import { IPAUFactory } from "./interfaces/IPAUFactory.sol";

contract PAUFactory is IPAUFactory, AccessControlEnumerable {

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    address public override registry;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address admin, address registry_) {
        require(registry_ != address(0), ZeroRegistry());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        registry = registry_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setRegistry(address newRegistry)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newRegistry != address(0), ZeroRegistry());

        emit RegistryUpdated(registry, newRegistry);

        registry = newRegistry;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IPAUFactory, AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(IPAUFactory).interfaceId || super.supportsInterface(interfaceId);
    }

    /**********************************************************************************************/
    /*** Deploy Function                                                                        ***/
    /**********************************************************************************************/

    function deploy(address admin) external override returns (address controller) {
        // Step 1: Deploy ALMProxy and RateLimits contracts with the factory as initial admin.

        ALMProxy   almProxy   = new ALMProxy(address(this));
        RateLimits rateLimits = new RateLimits(address(this));

        address accessControls = address(new AccessControls(admin));

        controller = address(new Controller({
            accessControls_ : accessControls,
            proxy_          : address(almProxy),
            rateLimits_     : address(rateLimits),
            registry_       : registry
        }));

        // Step 2: Grant CONTROLLER role on ALMProxy and RateLimits to the Controller.

        almProxy.grantRole(almProxy.CONTROLLER(),     controller);
        rateLimits.grantRole(rateLimits.CONTROLLER(), controller);

        // Step 3: Grant _DEFAULT_ADMIN_ROLE on ALMProxy and RateLimits to the passed admin.

        almProxy.grantRole(DEFAULT_ADMIN_ROLE,   admin);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, admin);

        // Step 4: Revoke factory's own _DEFAULT_ADMIN_ROLE on ALMProxy and RateLimits.

        almProxy.revokeRole(DEFAULT_ADMIN_ROLE,   address(this));
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        emit PAUDeployed(
            admin,
            controller,
            accessControls,
            address(almProxy),
            address(rateLimits)
        );
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

}
