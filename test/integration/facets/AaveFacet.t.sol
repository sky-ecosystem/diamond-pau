// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IAaveFacet }              from "../../../src/facets/aave/IAaveFacet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";

import { AaveFacet } from "../../../src/facets/aave/AaveFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setAaveCollateral(address aToken, bool useAsCollateral) external;

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external;

    function getAaveMaxSlippage(address aToken) external view returns (uint256);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

abstract contract AaveFacet_TestBase is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new AaveFacet());

        vm.label(facet, "AaveFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setAaveMaxSlippage.selector,
            IAaveFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getAaveMaxSlippage.selector,
            IAaveFacet.getMaxSlippage.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.setAaveCollateral.selector,
            IAaveFacet.setCollateral.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("AAVE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "AAVE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

}

contract Controller_AaveFacet_Admin_Tests is AaveFacet_TestBase {

    /**********************************************************************************************/
    /*** setAaveMaxSlippage Tests                                                               ***/
    /**********************************************************************************************/

    function test_setMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setAaveMaxSlippage(makeAddr("aToken"), 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setAaveMaxSlippage(makeAddr("aToken"), 0.98e18);
    }

    function test_setMaxSlippage_aTokenZeroAddress() external {
        vm.prank(admin);
        vm.expectRevert("AaveFacet/aToken-zero-address");
        controller.setAaveMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address aToken = makeAddr("aToken");

        assertEq(controller.getAaveMaxSlippage(aToken), 0);

        vm.prank(admin);
        vm.expectEmit(address(controller));
        emit IAaveFacet.AaveMaxSlippageSet(aToken, 0.98e18);
        controller.setAaveMaxSlippage(aToken, 0.98e18);

        assertEq(controller.getAaveMaxSlippage(aToken), 0.98e18);

        vm.record();

        vm.prank(admin);
        vm.expectEmit(address(controller));
        emit IAaveFacet.AaveMaxSlippageSet(aToken, 0.99e18);
        controller.setAaveMaxSlippage(aToken, 0.99e18);

        assertEq(controller.getAaveMaxSlippage(aToken), 0.99e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

    /**********************************************************************************************/
    /*** setAaveCollateral Tests                                                                ***/
    /**********************************************************************************************/

    function test_setAaveCollateral_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setAaveCollateral(makeAddr("aToken"), true);
    }

    function test_setAaveCollateral_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setAaveCollateral(makeAddr("aToken"), true);
    }

    function test_setAaveCollateral_aTokenZeroAddress() external {
        vm.prank(admin);
        vm.expectRevert("AaveFacet/aToken-zero-address");
        controller.setAaveCollateral(address(0), true);
    }

}
