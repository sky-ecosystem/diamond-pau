// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl }           from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable } from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IERC165 }                  from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { IAccessControlRegistry } from "../../src/interfaces/IAccessControlRegistry.sol";

import { AccessControlRegistry } from "../../src/AccessControlRegistry.sol";

contract AccessControlRegistry_Tests is Test {

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal admin        = makeAddr("admin");
    address internal freezer      = makeAddr("freezer");
    address internal relayer      = makeAddr("relayer");
    address internal deployer     = makeAddr("deployer");
    address internal unauthorized = makeAddr("unauthorized");

    AccessControlRegistry internal registry;

    function setUp() external {
        vm.prank(deployer);
        registry = new AccessControlRegistry(admin);
    }

    function test_constructor() external {
        assertEq(registry.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    function test_removeRelayer_notFreezer() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                registry.FREEZER_ROLE()
            )
        );

        vm.prank(unauthorized);
        registry.removeRelayer(relayer);
    }

    function test_removeRelayer() external {
        vm.startPrank(admin);
        registry.grantRole(registry.FREEZER_ROLE(), freezer);
        registry.grantRole(registry.RELAYER_ROLE(), relayer);
        vm.stopPrank();

        assertEq(registry.hasRole(registry.RELAYER_ROLE(), relayer), true);

        vm.expectEmit(address(registry));
        emit IAccessControl.RoleRevoked(registry.RELAYER_ROLE(), relayer, freezer);

        vm.expectEmit(address(registry));
        emit IAccessControlRegistry.RelayerRemoved(relayer);

        vm.prank(freezer);
        registry.removeRelayer(relayer);

        assertEq(registry.hasRole(registry.RELAYER_ROLE(), relayer), false);
    }

    function test_supportsInterface() external view {
        assertEq(registry.supportsInterface(type(IAccessControlRegistry).interfaceId),   true);
        assertEq(registry.supportsInterface(type(IAccessControlEnumerable).interfaceId), true);
        assertEq(registry.supportsInterface(type(IAccessControl).interfaceId),           true);
        assertEq(registry.supportsInterface(type(IERC165).interfaceId),                  true);
    }

}
