// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IntegrationConfig, Wire } from "../../../src/interfaces/IntegrationStructs.sol";

import { IBeacon }     from "../../../src/interfaces/IBeacon.sol";
import { ICurveFacet } from "../../../src/facets/curve/ICurveFacet.sol";

import { CurveFacet } from "../../../src/facets/curve/CurveFacet.sol";

import { Controller_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setCurveMaxSlippage(address pool, uint256 maxSlippage) external;

    function getCurveMaxSlippage(address pool) external view returns (uint256);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

abstract contract CurveFacet_TestBase is Controller_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new CurveFacet());

        vm.label(facet, "CurveFacet");

        Wire[] memory wires = new Wire[](2);

        wires[0] = Wire(
            IControllerLike.setCurveMaxSlippage.selector,
            ICurveFacet.setMaxSlippage.selector
        );

        wires[1] = Wire(
            IControllerLike.getCurveMaxSlippage.selector,
            ICurveFacet.getMaxSlippage.selector
        );

        IntegrationConfig memory integrationConfig = IntegrationConfig({
            facet : facet,
            wires : wires
        });

        vm.prank(beaconAdmin);
        beacon.setIntegration("CURVE_FACET", integrationConfig);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "CURVE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

}

contract Controller_CurveFacet_Admin_Tests is CurveFacet_TestBase {

    function test_setCurveMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setCurveMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setCurveMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setCurveMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setCurveMaxSlippage_poolZeroAddress() external {
        vm.expectRevert("CurveFacet/pool-zero-address");
        vm.prank(admin);
        controller.setCurveMaxSlippage(address(0), 0.98e18);
    }

    function test_setCurveMaxSlippage() external {
        address pool = makeAddr("pool");

        assertEq(controller.getCurveMaxSlippage(pool), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICurveFacet.CurveMaxSlippageSet({ pool: pool, maxSlippage: 0.98e18 });

        vm.prank(admin);
        controller.setCurveMaxSlippage(pool, 0.98e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getCurveMaxSlippage(pool), 0.98e18);

        vm.expectEmit(address(controller));
        emit ICurveFacet.CurveMaxSlippageSet({ pool: pool, maxSlippage: 0.99e18 });

        vm.prank(admin);
        controller.setCurveMaxSlippage(pool, 0.99e18);

        assertEq(controller.getCurveMaxSlippage(pool), 0.99e18);
    }

}
