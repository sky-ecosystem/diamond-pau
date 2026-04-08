// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IntegrationConfig, Wire } from "../../src/interfaces/IntegrationStructs.sol";

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
    /*** setIntegration Tests                                                                   ***/
    /**********************************************************************************************/

    function test_setIntegration_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : address(0),
            wires : new Wire[](0)
        });

        beacon.setIntegration(bytes32(0), integrationConfig);
    }

    function test_setIntegration() external {
        bytes32 integrationId = "SOME_INTEGRATION";

        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        Wire[] memory wires = new Wire[](3);
        wires[0] = Wire(callSelectors[0], delegateSelectors[0]);
        wires[1] = Wire(callSelectors[1], delegateSelectors[1]);
        wires[2] = Wire(callSelectors[2], delegateSelectors[2]);

        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : facet,
            wires : wires
        });

        vm.expectEmit(address(beacon));
        emit IBeacon.IntegrationSet(integrationId, integrationConfig);

        vm.prank(admin);
        beacon.setIntegration(integrationId, integrationConfig);

        IntegrationConfig memory returnedIntegrationConfig = beacon.getIntegrationConfig(integrationId);

        assertEq(returnedIntegrationConfig.facet,        facet);
        assertEq(returnedIntegrationConfig.wires.length, wires.length);

        assertEq(returnedIntegrationConfig.wires[0].callSelector,     wires[0].callSelector);
        assertEq(returnedIntegrationConfig.wires[0].delegateSelector, wires[0].delegateSelector);

        assertEq(returnedIntegrationConfig.wires[1].callSelector,     wires[1].callSelector);
        assertEq(returnedIntegrationConfig.wires[1].delegateSelector, wires[1].delegateSelector);

        assertEq(returnedIntegrationConfig.wires[2].callSelector,     wires[2].callSelector);
        assertEq(returnedIntegrationConfig.wires[2].delegateSelector, wires[2].delegateSelector);
    }

    /**********************************************************************************************/
    /*** removeIntegration Tests                                                                ***/
    /**********************************************************************************************/

    function test_removeIntegration_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeIntegration(bytes32(0));
    }

}
