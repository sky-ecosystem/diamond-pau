// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Dispatch, Integration, Config, Wire } from "../../src/interfaces/IntegrationStructs.sol";

import { IBeacon }     from "../../src/interfaces/IBeacon.sol";
import { IController } from "../../src/interfaces/IController.sol";

import { Controller_TestBase } from "./TestBase.t.sol";

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

interface IMockController is IController {

    function div(uint256 arg) external pure returns (uint256);

    function mul(uint256 arg) external pure returns (uint256);

}

contract ControllerIntegration_Tests is Controller_TestBase {

    IMockController internal controller;

    function setUp() external {
        controller = IMockController(_deploy());
    }

    /**********************************************************************************************/
    /*** Fallback Tests                                                                         ***/
    /**********************************************************************************************/

    function test_fallback_story() external {
        address facet1 = address(new MockFacet1());
        address facet2 = address(new MockFacet2());

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = IMockController.div.selector;
        callSelectors[1] = IMockController.mul.selector;

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.div.selector
            )
        );

        controller.div(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.mul.selector
            )
        );

        controller.mul(0);

        assertEq(beacon.integrations().length, 0);

        Dispatch[] memory dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 2);

        assertEq(dispatches[0].facet,            address(0));
        assertEq(dispatches[0].delegateSelector, bytes4(0));
        assertEq(dispatches[1].facet,            address(0));
        assertEq(dispatches[1].delegateSelector, bytes4(0));

        // Wire div to facet1.divideBy2 and mul to facet1.multiplyBy2

        Wire[] memory wires = new Wire[](2);
        wires[0] = Wire(IMockController.div.selector, MockFacet1.divideBy2.selector);
        wires[1] = Wire(IMockController.mul.selector, MockFacet1.multiplyBy2.selector);

        vm.prank(beaconAdmin);
        Config memory config = Config({
            facet : facet1,
            wires : wires
        });

        beacon.setIntegration("MOCK_FACET_1", config);

        assertEq(controller.div(12), 6);
        assertEq(controller.mul(12), 24);

        Integration[] memory integrations = beacon.integrations();

        assertEq(integrations.length, 1);

        assertEq(integrations[0].config.facet,        facet1);
        assertEq(integrations[0].config.wires.length, 2);

        assertEq(integrations[0].config.wires[0].callSelector,     IMockController.div.selector);
        assertEq(integrations[0].config.wires[0].delegateSelector, MockFacet1.divideBy2.selector);
        assertEq(integrations[0].config.wires[1].callSelector,     IMockController.mul.selector);
        assertEq(integrations[0].config.wires[1].delegateSelector, MockFacet1.multiplyBy2.selector);

        dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 2);

        assertEq(dispatches[0].facet,            facet1);
        assertEq(dispatches[0].delegateSelector, MockFacet1.divideBy2.selector);
        assertEq(dispatches[1].facet,            facet1);
        assertEq(dispatches[1].delegateSelector, MockFacet1.multiplyBy2.selector);

        // Re-wire div to facet2.divideBy4 (keeping mul to facet1.multiplyBy2)

        Wire[] memory facet1Wires = new Wire[](1);
        facet1Wires[0] = Wire(IMockController.mul.selector, MockFacet1.multiplyBy2.selector);

        Wire[] memory facet2DivWires = new Wire[](1);
        facet2DivWires[0] = Wire(IMockController.div.selector, MockFacet2.divideBy4.selector);

        vm.startPrank(beaconAdmin);
        beacon.setIntegration("MOCK_FACET_1", Config({
            facet : facet1,
            wires : facet1Wires
        }));

        beacon.setIntegration("MOCK_FACET_2", Config({
            facet : facet2,
            wires : facet2DivWires
        }));
        vm.stopPrank();

        assertEq(controller.div(12), 3);
        assertEq(controller.mul(12), 24);

        integrations = beacon.integrations();

        assertEq(integrations.length, 2);

        assertEq(integrations[0].config.facet,        facet1);
        assertEq(integrations[0].config.wires.length, 1);

        assertEq(integrations[0].config.wires[0].callSelector,     IMockController.mul.selector);
        assertEq(integrations[0].config.wires[0].delegateSelector, MockFacet1.multiplyBy2.selector);

        assertEq(integrations[1].config.facet,        facet2);
        assertEq(integrations[1].config.wires.length, 1);

        assertEq(integrations[1].config.wires[0].callSelector,     IMockController.div.selector);
        assertEq(integrations[1].config.wires[0].delegateSelector, MockFacet2.divideBy4.selector);

        dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 2);

        assertEq(dispatches[0].facet,            facet2);
        assertEq(dispatches[0].delegateSelector, MockFacet2.divideBy4.selector);
        assertEq(dispatches[1].facet,            facet1);
        assertEq(dispatches[1].delegateSelector, MockFacet1.multiplyBy2.selector);

        // Remove facet1 integration and route both selectors through facet2

        Wire[] memory facet2Both = new Wire[](2);
        facet2Both[0] = Wire(IMockController.div.selector, MockFacet2.divideBy4.selector);
        facet2Both[1] = Wire(IMockController.mul.selector, MockFacet2.multiplyBy4.selector);

        vm.startPrank(beaconAdmin);
        beacon.removeIntegration("MOCK_FACET_1");

        beacon.setIntegration("MOCK_FACET_2", Config({
            facet : facet2,
            wires : facet2Both
        }));
        vm.stopPrank();

        assertEq(controller.div(12), 3);
        assertEq(controller.mul(12), 48);

        integrations = beacon.integrations();

        assertEq(integrations.length, 1);

        assertEq(integrations[0].config.facet,        facet2);
        assertEq(integrations[0].config.wires.length, 2);

        assertEq(integrations[0].config.wires[0].callSelector,     IMockController.div.selector);
        assertEq(integrations[0].config.wires[0].delegateSelector, MockFacet2.divideBy4.selector);

        assertEq(integrations[0].config.wires[1].callSelector,     IMockController.mul.selector);
        assertEq(integrations[0].config.wires[1].delegateSelector, MockFacet2.multiplyBy4.selector);

        dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 2);

        assertEq(dispatches[0].facet,            facet2);
        assertEq(dispatches[0].delegateSelector, MockFacet2.divideBy4.selector);
        assertEq(dispatches[1].facet,            facet2);
        assertEq(dispatches[1].delegateSelector, MockFacet2.multiplyBy4.selector);

        vm.prank(beaconAdmin);
        beacon.removeIntegration("MOCK_FACET_2");

        integrations = beacon.integrations();

        assertEq(integrations.length, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.div.selector
            )
        );

        controller.div(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.mul.selector
            )
        );

        controller.mul(0);

        assertEq(beacon.integrations().length, 0);

        dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 2);

        assertEq(dispatches[0].facet,            address(0));
        assertEq(dispatches[0].delegateSelector, bytes4(0));
        assertEq(dispatches[1].facet,            address(0));
        assertEq(dispatches[1].delegateSelector, bytes4(0));
    }

}
