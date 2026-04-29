// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICurveFacet }             from "../../../src/facets/curve/ICurveFacet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";

import { CurveFacet } from "../../../src/facets/curve/CurveFacet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

interface IControllerLike {

    function setMaxSlippage(address pool, uint256 maxSlippage) external;

    function getMaxSlippage(address pool) external view returns (uint256);

    function updateIntegrations(bytes32[] memory integrationIds) external;

}

contract Controller_CurveFacet_Tests is Integration_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        address facet = address(new CurveFacet());

        vm.label(facet, "CurveFacet");

        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](2);

        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.setMaxSlippage.selector,
            ICurveFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IControllerLike.getMaxSlippage.selector,
            ICurveFacet.getMaxSlippage.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("CURVE_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "CURVE_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

    /**********************************************************************************************/
    /*** setMaxSlippage Tests                                                                   ***/
    /**********************************************************************************************/

    function test_setMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setMaxSlippage(makeAddr("pool"), 0.98e18);
    }

    function test_setMaxSlippage_poolZeroAddress() external {
        vm.expectRevert("CurveFacet/pool-zero-address");
        vm.prank(admin);
        controller.setMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address pool = makeAddr("pool");

        assertEq(controller.getMaxSlippage(pool), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICurveFacet.CurveMaxSlippageSet(pool, 0.98e18);

        vm.prank(admin);
        controller.setMaxSlippage(pool, 0.98e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.getMaxSlippage(pool), 0.98e18);

        vm.expectEmit(address(controller));
        emit ICurveFacet.CurveMaxSlippageSet(pool, 0.99e18);

        vm.prank(admin);
        controller.setMaxSlippage(pool, 0.99e18);

        assertEq(controller.getMaxSlippage(pool), 0.99e18);
    }

    /**********************************************************************************************/
    /*** setDepositRateLimit Tests                                                              ***/
    /**********************************************************************************************/

    // TODO

    /**********************************************************************************************/
    /*** setSwapRateLimit Tests                                                                  ***/
    /**********************************************************************************************/

    // TODO

    /**********************************************************************************************/
    /*** setWithdrawRateLimit Tests                                                             ***/
    /**********************************************************************************************/

    // TODO

}
