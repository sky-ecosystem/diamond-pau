// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IUSDEFacet }              from "../../../src/facets/usde/IUSDEFacet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";

import { USDEFacet } from "../../../src/facets/usde/USDEFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setMinter(address minter) external;

    function updateIntegrations(bytes32[] memory integrationIds) external;

    function minter() external view returns (address);

}

contract Controller_USDEFacet_Tests is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new USDEFacet(makeAddr("susde"), makeAddr("usdc"), makeAddr("usde")));

        vm.label(facet, "USDEFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setMinter.selector,
            IUSDEFacet.setMinter.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.minter.selector,
            IUSDEFacet.minter.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("USDE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "USDE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroSusde() external {
        vm.expectRevert("USDEFacet/zero-susde");
        new USDEFacet(address(0), address(0), address(0));
    }

    function test_constructor_zeroUSDC() external {
        vm.expectRevert("USDEFacet/zero-usdc");
        new USDEFacet(makeAddr("susde"), address(0), address(0));
    }

    function test_constructor_zeroUSDE() external {
        vm.expectRevert("USDEFacet/zero-usde");
        new USDEFacet(makeAddr("susde"), makeAddr("usdc"), address(0));
    }

    function test_constructor() external {
        address susde = makeAddr("susde");
        address usdc  = makeAddr("usdc");
        address usde  = makeAddr("usde");

        USDEFacet facet = new USDEFacet(susde, usdc, usde);

        assertEq(facet.susde(), susde);
        assertEq(facet.usdc(),  usdc);
        assertEq(facet.usde(),  usde);
    }

    /**********************************************************************************************/
    /*** setMinter Tests                                                                        ***/
    /**********************************************************************************************/

    function test_setMinter_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMinter(address(0));
    }

    function test_setMinter_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setMinter(address(0));
    }

    function test_setMinter_zeroMinter() external {
        vm.expectRevert("USDEFacet/zero-minter");
        vm.prank(admin);
        controller.setMinter(address(0));
    }

    function test_setMinter() external {
        assertEq(controller.minter(), address(0));

        address minter = makeAddr("minter");

        vm.record();

        vm.expectEmit(address(controller));
        emit IUSDEFacet.USDEMinterSet(minter);

        vm.prank(admin);
        controller.setMinter(minter);

        assertEq(controller.minter(), minter);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

}
