// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl }           from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable } from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IERC165 }                  from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { IPAUFactory } from "../../src/interfaces/IPAUFactory.sol";

import { PAUFactory } from "../../src/PAUFactory.sol";

contract PAUFactory_Tests is Test {

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal admin    = makeAddr("admin");
    address internal deployer = makeAddr("deployer");
    address internal registry = makeAddr("registry");

    PAUFactory internal factory;

    function setUp() external {
        vm.prank(deployer);
        factory = new PAUFactory(admin, registry);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroRegistry() external {
        vm.expectRevert(IPAUFactory.ZeroRegistry.selector);
        new PAUFactory(admin, address(0));
    }

    function test_constructor() external view {
        assertEq(factory.registry(), registry);
        assertEq(factory.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    /**********************************************************************************************/
    /*** supportsInterface Tests                                                                ***/
    /**********************************************************************************************/

    function test_supportsInterface() external view {
        assertEq(factory.supportsInterface(type(IPAUFactory).interfaceId),              true);
        assertEq(factory.supportsInterface(type(IAccessControlEnumerable).interfaceId), true);
        assertEq(factory.supportsInterface(type(IAccessControl).interfaceId),           true);
        assertEq(factory.supportsInterface(type(IERC165).interfaceId),                  true);
    }

}
