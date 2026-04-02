// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

import { Controller_TestBase } from "./TestBase.t.sol";

contract MockFacet1 {

    function divide(uint256 arg) external pure returns (uint256) {
        return arg / 2;
    }

    function multiply(uint256 arg) external pure returns (uint256) {
        return arg * 2;
    }

}

contract MockFacet2 {

    function divide(uint256 arg) external pure returns (uint256) {
        return arg / 4;
    }

    function multiply(uint256 arg) external pure returns (uint256) {
        return arg * 4;
    }

}

interface IMockController {

    function foo(uint256 arg) external pure returns (uint256);

}

contract ControllerIntegration_Tests is Controller_TestBase {

    IController internal controller;

    function setUp() external {
        controller = IController(_deploy());
    }

    /**********************************************************************************************/
    /*** addWire Tests                                                                          ***/
    /**********************************************************************************************/

    function test_addWire_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.addWire(address(0), IController.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire_notValidFacet() external {
        address facet = makeAddr("facet");

        vm.expectRevert(abi.encodeWithSelector(IController.InvalidFacet.selector, facet));
        vm.prank(admin);
        controller.addWire(facet, IController.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire() external {
        address facet = address(new MockFacet1());

        bytes4 callSelector     = 0x12345678;
        bytes4 delegateSelector = 0x87654321;

        vm.prank(facetValidator);
        factory.setValidFacet(facet, true);

        vm.expectEmit(address(controller));
        emit IController.WireAdded(callSelector, delegateSelector, facet);

        vm.prank(admin);
        controller.addWire(facet, IController.Wire(callSelector, delegateSelector));

        IController.Dispatch memory dispatch = controller.getDispatch(callSelector);

        assertEq(dispatch.facet,            facet);
        assertEq(dispatch.delegateSelector, delegateSelector);

        vm.expectEmit(address(controller));
        emit IController.WireRemoved(callSelector);

        vm.prank(admin);
        controller.removeWire(callSelector);

        dispatch = controller.getDispatch(callSelector);

        assertEq(dispatch.facet,            address(0));
        assertEq(dispatch.delegateSelector, bytes4(0));
    }

    /**********************************************************************************************/
    /*** addWires Tests                                                                         ***/
    /**********************************************************************************************/

    function test_addWires_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.addWires(address(0), new IController.Wire[](0));
    }

    function test_addWires_notValidFacet() external {
        address facet = address(new MockFacet1());

        vm.expectRevert(abi.encodeWithSelector(IController.InvalidFacet.selector, facet));
        vm.prank(admin);
        controller.addWires(facet, new IController.Wire[](2));
    }

    /**********************************************************************************************/
    /*** removeWire Tests                                                                       ***/
    /**********************************************************************************************/

    function test_removeWire_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.removeWire(bytes4(0));
    }

    /**********************************************************************************************/
    /*** removeWires Tests                                                                      ***/
    /**********************************************************************************************/

    function test_removeWires_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.removeWires(new bytes4[](0));
    }

    /**********************************************************************************************/
    /*** removeAllWiresFor Tests                                                                ***/
    /**********************************************************************************************/

    function test_removeAllWiresFor_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.removeAllWiresFor(address(0));
    }

    /**********************************************************************************************/
    /*** Fallback Tests                                                                         ***/
    /**********************************************************************************************/

    function test_fallback_facetNotFound() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.foo.selector
            )
        );

        IMockController(address(controller)).foo(10);

        address facet1 = address(new MockFacet1());
        address facet2 = address(new MockFacet2());

        vm.startPrank(facetValidator);
        factory.setValidFacet(facet1, true);
        factory.setValidFacet(facet2, true);
        vm.stopPrank();

        vm.prank(admin);
        controller.addWire(facet1, IController.Wire(IMockController.foo.selector, MockFacet1.divide.selector));

        assertEq(IMockController(address(controller)).foo(12), 6);

        vm.startPrank(admin);
        controller.removeWire(IMockController.foo.selector);
        controller.addWire(facet1, IController.Wire(IMockController.foo.selector, MockFacet1.multiply.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 24);

        vm.startPrank(admin);
        controller.removeWire(IMockController.foo.selector);
        controller.addWire(facet2, IController.Wire(IMockController.foo.selector, MockFacet2.multiply.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 48);

        vm.startPrank(admin);
        controller.removeWire(IMockController.foo.selector);
        controller.addWire(facet2, IController.Wire(IMockController.foo.selector, MockFacet2.divide.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 3);

        vm.prank(admin);
        controller.removeAllWiresFor(facet2);

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.CallSelectorNotWired.selector,
                IMockController.foo.selector
            )
        );

        IMockController(address(controller)).foo(10);
    }
}
