// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController }  from "../../src/interfaces/IController.sol";
import { IPAURegistry } from "../../src/interfaces/IPAURegistry.sol";

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
    /*** optInToFacet Tests                                                                     ***/
    /**********************************************************************************************/

    function test_optInToFacet_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optInToFacet("MockFacet1");
    }

    function test_optInToFacet() external {
        assertEq(controller.isFacetWhitelisted("MockFacet1"), false);

        vm.prank(admin);
        controller.optInToFacet("MockFacet1");

        assertEq(controller.isFacetWhitelisted("MockFacet1"), true);
    }

    /**********************************************************************************************/
    /*** optOutOfFacet Tests                                                                    ***/
    /**********************************************************************************************/

    function test_optOutOfFacet_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.optOutOfFacet("MockFacet1");
    }

    function test_optOutOfFacet() external {
        vm.prank(admin);
        controller.optInToFacet("MockFacet1");

        assertEq(controller.isFacetWhitelisted("MockFacet1"), true);

        vm.prank(admin);
        controller.optOutOfFacet("MockFacet1");

        assertEq(controller.isFacetWhitelisted("MockFacet1"), false);
    }

    /**********************************************************************************************/
    /*** setAllowAllFacets Tests                                                                ***/
    /**********************************************************************************************/

    function test_setAllowAllFacets_notAdmin() external {
        vm.expectRevert(abi.encodeWithSelector(IController.NotAdmin.selector, unauthorized));
        vm.prank(unauthorized);
        controller.setAllowAllFacets(false);
    }

    function test_setAllowAllFacets() external {
        assertEq(controller.allowAllFacets(), true);

        vm.prank(admin);
        controller.setAllowAllFacets(false);

        assertEq(controller.allowAllFacets(), false);

        vm.prank(admin);
        controller.setAllowAllFacets(true);

        assertEq(controller.allowAllFacets(), true);
    }

    /**********************************************************************************************/
    /*** Fallback Tests (registry-based dispatch)                                               ***/
    /**********************************************************************************************/

    function test_fallback_story() external {
        address facet1 = address(new MockFacet1());
        address facet2 = address(new MockFacet2());

        // Calls revert before any wiring

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

        // Register facets on registry and wire them

        vm.startPrank(registryAdmin);

        registry.registerFacet("MockFacet1", facet1);
        registry.registerFacet("MockFacet2", facet2);

        IPAURegistry.Wire[] memory wires = new IPAURegistry.Wire[](2);
        wires[0] = IPAURegistry.Wire(IMockController.div.selector, MockFacet1.divideBy2.selector);
        wires[1] = IPAURegistry.Wire(IMockController.mul.selector, MockFacet1.multiplyBy2.selector);

        string[] memory identifiers = new string[](2);
        identifiers[0] = "MockFacet1";
        identifiers[1] = "MockFacet1";

        registry.addWirings(wires, identifiers);

        vm.stopPrank();

        // Controller (allowAllFacets=true by default) can call through

        assertEq(controller.div(12), 6);
        assertEq(controller.mul(12), 24);

        IController.Dispatch memory dispatch = controller.getDispatch(IMockController.div.selector);
        assertEq(dispatch.facet,            facet1);
        assertEq(dispatch.delegateSelector, MockFacet1.divideBy2.selector);

        // Re-wire div to facet2.divideBy4 via registry

        vm.startPrank(registryAdmin);
        registry.removeWiring(IMockController.div.selector);
        registry.addWiring(
            IMockController.div.selector,
            MockFacet2.divideBy4.selector,
            "MockFacet2"
        );
        vm.stopPrank();

        assertEq(controller.div(12), 3);
        assertEq(controller.mul(12), 24);

        // Re-wire mul to facet2.multiplyBy4 via registry

        vm.startPrank(registryAdmin);
        registry.removeWiring(IMockController.mul.selector);
        registry.addWiring(
            IMockController.mul.selector,
            MockFacet2.multiplyBy4.selector,
            "MockFacet2"
        );
        vm.stopPrank();

        assertEq(controller.div(12), 3);
        assertEq(controller.mul(12), 48);

        // Remove wiring — calls revert again

        vm.startPrank(registryAdmin);
        registry.removeWiring(IMockController.div.selector);
        registry.removeWiring(IMockController.mul.selector);
        vm.stopPrank();

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
    }

    /**********************************************************************************************/
    /*** Whitelist Tests (allowAllFacets = false)                                               ***/
    /**********************************************************************************************/

    function test_fallback_whitelistEnforcement() external {
        address facet1 = address(new MockFacet1());

        // Register and wire facet on registry

        vm.startPrank(registryAdmin);
        registry.registerFacet("MockFacet1", facet1);
        registry.addWiring(
            IMockController.div.selector,
            MockFacet1.divideBy2.selector,
            "MockFacet1"
        );
        vm.stopPrank();

        // Works with allowAllFacets=true (default)
        assertEq(controller.div(12), 6);

        // Disable allowAllFacets
        vm.prank(admin);
        controller.setAllowAllFacets(false);

        // Now fails because MockFacet1 is not whitelisted
        vm.expectRevert(
            abi.encodeWithSelector(
                IController.FacetNotWhitelisted.selector,
                IMockController.div.selector,
                "MockFacet1"
            )
        );
        controller.div(12);

        // Opt in to MockFacet1
        vm.prank(admin);
        controller.optInToFacet("MockFacet1");

        // Now works
        assertEq(controller.div(12), 6);

        // Opt out
        vm.prank(admin);
        controller.optOutOfFacet("MockFacet1");

        // Fails again
        vm.expectRevert(
            abi.encodeWithSelector(
                IController.FacetNotWhitelisted.selector,
                IMockController.div.selector,
                "MockFacet1"
            )
        );
        controller.div(12);

        // Re-enable allowAllFacets
        vm.prank(admin);
        controller.setAllowAllFacets(true);

        // Works again
        assertEq(controller.div(12), 6);
    }

}
