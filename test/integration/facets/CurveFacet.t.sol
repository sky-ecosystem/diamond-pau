// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICurveFacet } from "../../../src/interfaces/facets/ICurveFacet.sol";
import { IController } from "../../../src/interfaces/IController.sol";

import { CurveFacet } from "../../../src/libraries/CurveLib.sol";

import { ControllerTestBase } from "../ControllerTestBase.t.sol";

interface IControllerLike is IController {

    function curveMaxSlippages(address pool) external view returns (uint256);

    function setCurveMaxSlippage(address pool, uint256 maxSlippage) external;

}

contract CurveFacet_Base is ControllerTestBase {

    IControllerLike internal controller;

    function setUp() public override {
        super.setUp();

        controller = IControllerLike(controllerAddress);

        // Wire the Curve facet.

        vm.startPrank(admin);

        _wireCurveFacet();

        vm.stopPrank();
    }

    // NOTE: Only wires the functions needed for the tests.
    //       If more functions are needed in future tests, they should be wired here.
    function _wireCurveFacet() internal {
        address curveFacet = address(new CurveFacet());

        vm.label(curveFacet, "CurveFacet");

        // Controller.setCurveMaxSlippage() -> CurveFacet.setMaxSlippage()
        controller.setDispatch(
            IControllerLike.setCurveMaxSlippage.selector,
            curveFacet,
            ICurveFacet.setMaxSlippage.selector
        );

        // Controller.curveMaxSlippages() -> CurveFacet.maxSlippages()
        controller.setDispatch(
            IControllerLike.curveMaxSlippages.selector,
            curveFacet,
            ICurveFacet.maxSlippages.selector
        );
    }

}

contract ControllerIntegration_CurveFacet_SetCurveMaxSlippage_Tests is CurveFacet_Base {

    function test_setCurveMaxSlippage_reentrancy() external {
        _setControllerEntered();
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

        assertEq(controller.curveMaxSlippages(pool), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICurveFacet.MaxSlippageSet(pool, 0.98e18);

        vm.prank(admin);
        controller.setCurveMaxSlippage(pool, 0.98e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(controller.curveMaxSlippages(pool), 0.98e18);

        vm.expectEmit(address(controller));
        emit ICurveFacet.MaxSlippageSet(pool, 0.99e18);

        vm.prank(admin);
        controller.setCurveMaxSlippage(pool, 0.99e18);

        assertEq(controller.curveMaxSlippages(pool), 0.99e18);
    }

}
