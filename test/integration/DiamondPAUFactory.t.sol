// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { AccessControls }      from "../../src/AccessControls.sol";
import { ALMProxy }            from "../../src/ALMProxy.sol";
import { Controller }          from "../../src/Controller.sol";
import { DiamondPAUFactory }   from "../../src/DiamondPAUFactory.sol";
import { IDiamondPAUFactory }  from "../../src/interfaces/IDiamondPAUFactory.sol";
import { RateLimits }          from "../../src/RateLimits.sol";

contract DiamondPAUFactory_Tests is Test {

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal admin = makeAddr("admin");

    DiamondPAUFactory internal factory;

    /**********************************************************************************************/
    /*** Setup                                                                                  ***/
    /**********************************************************************************************/

    function setUp() external {
        factory = new DiamondPAUFactory();
    }

    /**********************************************************************************************/
    /*** deployDiamondPAU Tests                                                                 ***/
    /**********************************************************************************************/

    function test_deployDiamondPAU() external {
        IDiamondPAUFactory.DiamondPAU memory system = factory.deployDiamondPAU(admin);

        AccessControls accessControls = system.accessControls;
        ALMProxy       almProxy       = system.almProxy;
        Controller     controller     = system.controller;
        RateLimits     rateLimits     = system.rateLimits;

        // Controller references are wired correctly.

        assertEq(controller.accessControls(), address(accessControls));
        assertEq(controller.proxy(),          address(almProxy));
        assertEq(controller.rateLimits(),     address(rateLimits));

        // CONTROLLER role granted on ALMProxy and RateLimits to the Controller.

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     address(controller)), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(controller)), true);

        // DEFAULT_ADMIN_ROLE granted to admin on all three.

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE,       admin), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     admin), true);

        // Only one admin member on AccessControls (ALMProxy and RateLimits ACL is not enumerable).

        assertEq(accessControls.getRoleMember(DEFAULT_ADMIN_ROLE, 0), admin);

        assertEq(accessControls.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);

        // Factory has NO DEFAULT_ADMIN_ROLE on any contract.

        assertEq(accessControls.hasRole(DEFAULT_ADMIN_ROLE, address(factory)), false);
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE,       address(factory)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE,     address(factory)), false);

        // Factory has NO CONTROLLER role on ALMProxy or RateLimits.

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     address(factory)), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(factory)), false);
    }

    function test_deployDiamondPAU_event() external {
        uint256 nonce = vm.getNonce(address(factory));

        address expectedAccessControls = vm.computeCreateAddress(address(factory), nonce);
        address expectedAlmProxy       = vm.computeCreateAddress(address(factory), nonce + 1);
        address expectedRateLimits     = vm.computeCreateAddress(address(factory), nonce + 2);
        address expectedController     = vm.computeCreateAddress(address(factory), nonce + 3);

        vm.expectEmit(address(factory));
        emit IDiamondPAUFactory.DiamondPAUDeployed(
            admin,
            expectedAccessControls,
            expectedAlmProxy,
            expectedController,
            expectedRateLimits
        );

        factory.deployDiamondPAU(admin);
    }

    function test_deployDiamondPAU_adminCanManageRoles() external {
        IDiamondPAUFactory.DiamondPAU memory system = factory.deployDiamondPAU(admin);

        address newController = makeAddr("newController");
        address freezer       = makeAddr("freezer");
        address relayer       = makeAddr("relayer");

        vm.startPrank(admin);

        // Admin can grant roles on AccessControls.

        system.accessControls.grantRole(system.accessControls.FREEZER_ROLE(), freezer);
        system.accessControls.grantRole(system.accessControls.RELAYER_ROLE(), relayer);

        assertEq(system.accessControls.hasRole(system.accessControls.FREEZER_ROLE(), freezer), true);
        assertEq(system.accessControls.hasRole(system.accessControls.RELAYER_ROLE(), relayer), true);

        // Admin can grant CONTROLLER role on ALMProxy and RateLimits.

        system.almProxy.grantRole(system.almProxy.CONTROLLER(),     newController);
        system.rateLimits.grantRole(system.rateLimits.CONTROLLER(), newController);

        assertEq(system.almProxy.hasRole(system.almProxy.CONTROLLER(),     newController), true);
        assertEq(system.rateLimits.hasRole(system.rateLimits.CONTROLLER(), newController), true);

        vm.stopPrank();
    }

    function test_deployDiamondPAU_multipleDeployments() external {
        IDiamondPAUFactory.DiamondPAU memory system1 = factory.deployDiamondPAU(admin);
        IDiamondPAUFactory.DiamondPAU memory system2 = factory.deployDiamondPAU(admin);

        // Each deployment produces distinct contract addresses.
        assertNotEq(address(system1.accessControls), address(system2.accessControls));
        assertNotEq(address(system1.almProxy),       address(system2.almProxy));
        assertNotEq(address(system1.controller),     address(system2.controller));
        assertNotEq(address(system1.rateLimits),     address(system2.rateLimits));
    }

}
