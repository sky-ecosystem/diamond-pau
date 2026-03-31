// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ALMProxy }       from "./ALMProxy.sol";
import { AccessControls } from "./AccessControls.sol";
import { Controller }     from "./Controller.sol";
import { RateLimits }     from "./RateLimits.sol";

import { IDiamondPAUFactory } from "./interfaces/IDiamondPAUFactory.sol";

contract DiamondPAUFactory is IDiamondPAUFactory {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    /**********************************************************************************************/
    /*** Deployer function                                                                      ***/
    /**********************************************************************************************/

    function deployDiamondPAU(address admin) external returns (DiamondPAU memory system) {
        // Step 1: Deploy all contracts with the factory as initial admin.

        system.accessControls = new AccessControls(admin);
        system.almProxy       = new ALMProxy(address(this));
        system.rateLimits     = new RateLimits(address(this));

        system.controller = new Controller({
            accessControls_ : address(system.accessControls),
            proxy_          : address(system.almProxy),
            rateLimits_     : address(system.rateLimits)
        });

        // Step 2: Grant CONTROLLER role on ALMProxy and RateLimits to the Controller.

        system.almProxy.grantRole(system.almProxy.CONTROLLER(),     address(system.controller));
        system.rateLimits.grantRole(system.rateLimits.CONTROLLER(), address(system.controller));

        // Step 3: Grant DEFAULT_ADMIN_ROLE on ALMProxy and RateLimits to the passed admin.

        system.almProxy.grantRole(DEFAULT_ADMIN_ROLE,   admin);
        system.rateLimits.grantRole(DEFAULT_ADMIN_ROLE, admin);

        // Step 4: Revoke factory's own DEFAULT_ADMIN_ROLE on ALMProxy and RateLimits.

        system.almProxy.revokeRole(DEFAULT_ADMIN_ROLE,   address(this));
        system.rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, address(this));

        emit DiamondPAUDeployed(
            admin,
            address(system.accessControls),
            address(system.almProxy),
            address(system.controller),
            address(system.rateLimits)
        );
    }

}
