// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IBeacon } from "../../src/interfaces/IBeacon.sol";

import { Beacon } from "../../src/Beacon.sol";

contract MockFacet1 {

    function divideBy2(uint256 arg) external pure returns (uint256) {
        return arg / 2;
    }

    function multiplyBy2(uint256 arg) external pure returns (uint256) {
        return arg * 2;
    }

}

contract MockFacet2 {

    function divideBy4(uint256 arg) external pure returns (uint256) {
        return arg / 4;
    }

    function multiplyBy4(uint256 arg) external pure returns (uint256) {
        return arg * 4;
    }

}

contract BeaconIntegration_Tests is Test {

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    IBeacon internal beacon;

    address internal admin        = makeAddr("admin");
    address internal unauthorized = makeAddr("unauthorized");

    function setUp() external {
        beacon = new Beacon(admin);
    }

    /**********************************************************************************************/
    /*** addWire Tests                                                                          ***/
    /**********************************************************************************************/

    function test_addWire_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.addWire(address(0), IBeacon.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire() external {
        address facet = address(new MockFacet1());

        bytes4 callSelector     = 0x12345678;
        bytes4 delegateSelector = 0x87654321;

        vm.expectEmit(address(beacon));
        emit IBeacon.WireAdded(callSelector, delegateSelector, facet);

        vm.prank(admin);
        beacon.addWire(facet, IBeacon.Wire(callSelector, delegateSelector));

        IBeacon.Dispatch memory dispatch = beacon.getDispatch(callSelector);

        assertEq(dispatch.facet,            facet);
        assertEq(dispatch.delegateSelector, delegateSelector);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelector);

        vm.prank(admin);
        beacon.removeWire(callSelector);

        dispatch = beacon.getDispatch(callSelector);

        assertEq(dispatch.facet,            address(0));
        assertEq(dispatch.delegateSelector, bytes4(0));
    }

    /**********************************************************************************************/
    /*** addWires Tests                                                                         ***/
    /**********************************************************************************************/

    function test_addWires_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.addWires(address(0), new IBeacon.Wire[](0));
    }

    /**********************************************************************************************/
    /*** removeWire Tests                                                                       ***/
    /**********************************************************************************************/

    function test_removeWire_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeWire(bytes4(0));
    }

    /**********************************************************************************************/
    /*** removeWires Tests                                                                      ***/
    /**********************************************************************************************/

    function test_removeWires_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeWires(new bytes4[](0));
    }

    /**********************************************************************************************/
    /*** removeAllWiresFor Tests                                                                ***/
    /**********************************************************************************************/

    function test_removeAllWiresFor_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeAllWiresFor(address(0));
    }

}
