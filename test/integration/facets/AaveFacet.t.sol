// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IAaveFacet }  from "../../../src/interfaces/facets/IAaveFacet.sol";
import { IController } from "../../../src/interfaces/IController.sol";

import { AaveFacet } from "../../../src/libraries/AaveLib.sol";

import { ControllerTestBase } from "../ControllerTestBase.t.sol";

interface IControllerLike is IController {

    function aaveMaxSlippages(address aToken) external view virtual returns (uint256);

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external virtual;

}

contract AaveFacet_Base is ControllerTestBase {

    IControllerLike internal controller;

    function setUp() public override {
        super.setUp();

        controller = IControllerLike(controllerAddress);

        // Wire the Aave facet.

        vm.startPrank(admin);

        _wireAaveFacet();

        vm.stopPrank();
    }

    // NOTE: Only wires the functions needed for the tests.
    //       If more functions are needed in future tests, they should be wired here.
    function _wireAaveFacet() internal {
        address aaveFacet = address(new AaveFacet());

        vm.label(aaveFacet, "AaveFacet");

        // Controller.setAaveMaxSlippage() -> AaveFacet.setMaxSlippage()
        controller.setFacet(
            IControllerLike.setAaveMaxSlippage.selector,
            aaveFacet,
            IAaveFacet.setMaxSlippage.selector
        );

        // Controller.aaveMaxSlippages() -> AaveFacet.maxSlippages()
        controller.setFacet(
            IControllerLike.aaveMaxSlippages.selector,
            aaveFacet,
            IAaveFacet.maxSlippages.selector
        );
    }

}

contract ControllerIntegration_AaveFacet_SetMaxExchangeRate_Tests is AaveFacet_Base {

    function test_setMaxSlippage_reentrancy() external {
        _setControllerEntered();
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

        assertEq(controller.aaveMaxSlippages(aToken), 0);

        vm.prank(admin);
        vm.expectEmit(address(controller));
        emit IAaveFacet.MaxSlippageSet(aToken, 0.98e18);
        controller.setAaveMaxSlippage(aToken, 0.98e18);

        assertEq(controller.aaveMaxSlippages(aToken), 0.98e18);

        vm.record();

        vm.prank(admin);
        vm.expectEmit(address(controller));
        emit IAaveFacet.MaxSlippageSet(aToken, 0.99e18);
        controller.setAaveMaxSlippage(aToken, 0.99e18);

        assertEq(controller.aaveMaxSlippages(aToken), 0.99e18);

        _assertReentrancyGuardWrittenToTwice();
    }

}
