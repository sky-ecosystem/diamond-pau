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
    /*** addDispatch Tests                                                                      ***/
    /**********************************************************************************************/

    function test_addDispatch_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.addDispatch(0x12345678, IController.Dispatch(address(0), 0x87654321));
    }

    function test_addDispatch() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        vm.expectEmit(address(controller));
        emit IController.DispatchAdded(callSelector, facet, delegateSelector);

        vm.prank(admin);
        controller.addDispatch(callSelector, IController.Dispatch(facet, delegateSelector));

        IController.Dispatch memory dispatch = controller.getDispatch(callSelector);

        assertEq(dispatch.facet,            facet);
        assertEq(dispatch.delegateSelector, delegateSelector);

        vm.expectEmit(address(controller));
        emit IController.DispatchRemoved(callSelector);

        vm.prank(admin);
        controller.removeDispatch(callSelector);

        dispatch = controller.getDispatch(callSelector);

        assertEq(dispatch.facet,            address(0));
        assertEq(dispatch.delegateSelector, bytes4(0));
    }

    /**********************************************************************************************/
    /*** Fallback Tests                                                                         ***/
    /**********************************************************************************************/

    function test_fallback_facetNotFound() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IController.DispatchNotFound.selector,
                IMockController.foo.selector
            )
        );

        IMockController(address(controller)).foo(10);

        address facet1 = address(new MockFacet1());
        address facet2 = address(new MockFacet2());

        vm.prank(admin);
        controller.addDispatch(IMockController.foo.selector, IController.Dispatch(facet1, MockFacet1.divide.selector));

        assertEq(IMockController(address(controller)).foo(12), 6);

        vm.startPrank(admin);
        controller.removeDispatch(IMockController.foo.selector);
        controller.addDispatch(IMockController.foo.selector, IController.Dispatch(facet1, MockFacet1.multiply.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 24);

        vm.startPrank(admin);
        controller.removeDispatch(IMockController.foo.selector);
        controller.addDispatch(IMockController.foo.selector, IController.Dispatch(facet2, MockFacet2.multiply.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 48);

        vm.startPrank(admin);
        controller.removeDispatch(IMockController.foo.selector);
        controller.addDispatch(IMockController.foo.selector, IController.Dispatch(facet2, MockFacet2.divide.selector));
        vm.stopPrank();

        assertEq(IMockController(address(controller)).foo(12), 3);

        vm.prank(admin);
        controller.removeDispatch(IMockController.foo.selector);

        vm.expectRevert(
            abi.encodeWithSelector(
                IController.DispatchNotFound.selector,
                IMockController.foo.selector
            )
        );

        IMockController(address(controller)).foo(10);
    }
}
