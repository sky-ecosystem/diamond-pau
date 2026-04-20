// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IBasinFacet }             from "../../../src/facets/basin/IBasinFacet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";
import { IFacetBase }              from "../../../src/facets/IFacetBase.sol";

import { BasinFacet } from "../../../src/facets/basin/BasinFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function getBasinMaxSlippage(address basin) external view returns (uint256);

    function setBasinMaxSlippage(address basin, uint256 maxSlippage) external;

    function LIMIT_BASIN_DEPOSIT() external pure returns (bytes32);

    function LIMIT_BASIN_WITHDRAW() external pure returns (bytes32);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

abstract contract BasinFacet_TestBase is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new BasinFacet());

        vm.label(facet, "BasinFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](4);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setBasinMaxSlippage.selector,
            IBasinFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getBasinMaxSlippage.selector,
            IBasinFacet.getMaxSlippage.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IControllerLike.LIMIT_BASIN_DEPOSIT.selector,
            IBasinFacet.LIMIT_DEPOSIT.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IControllerLike.LIMIT_BASIN_WITHDRAW.selector,
            IBasinFacet.LIMIT_WITHDRAW.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("BASIN_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "BASIN_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

}

contract Controller_BasinFacet_Admin_Tests is BasinFacet_TestBase {

    function test_setBasinMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setBasinMaxSlippage(makeAddr("basin"), 0.99e18);
    }

    function test_setBasinMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IFacetBase.AccessControlUnauthorizedAccount.selector,
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setBasinMaxSlippage(makeAddr("basin"), 0.99e18);
    }

    function test_setBasinMaxSlippage_basinZeroAddress() external {
        vm.expectRevert("BasinFacet/basin-zero-address");
        vm.prank(admin);
        controller.setBasinMaxSlippage(address(0), 0.99e18);
    }

    function test_setBasinMaxSlippage() external {
        address basin = makeAddr("basin");

        assertEq(controller.getBasinMaxSlippage(basin), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit IBasinFacet.BasinMaxSlippageSet(basin, 0.99e18);

        vm.prank(admin);
        controller.setBasinMaxSlippage(basin, 0.99e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getBasinMaxSlippage(basin), 0.99e18);

        vm.expectEmit(address(controller));
        emit IBasinFacet.BasinMaxSlippageSet(basin, 0.98e18);

        vm.prank(admin);
        controller.setBasinMaxSlippage(basin, 0.98e18);

        assertEq(controller.getBasinMaxSlippage(basin), 0.98e18);
    }

}

contract Controller_BasinFacet_View_Tests is BasinFacet_TestBase {

    function test_LIMIT_BASIN_DEPOSIT() external view {
        assertEq(controller.LIMIT_BASIN_DEPOSIT(), keccak256("LIMIT_BASIN_DEPOSIT"));
    }

    function test_LIMIT_BASIN_WITHDRAW() external view {
        assertEq(controller.LIMIT_BASIN_WITHDRAW(), keccak256("LIMIT_BASIN_WITHDRAW"));
    }

}
