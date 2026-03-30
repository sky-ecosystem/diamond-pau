// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IAaveFacet } from "../../../src/facets/aave/IAaveFacet.sol";
import { AaveFacet }  from "../../../src/facets/aave/AaveFacet.sol";

import { Controller_TestBase } from "../TestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IControllerLike {

    function setDispatch(bytes4 callSelector, address facet, bytes4 delegateSelector) external;

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external;

    function getAaveMaxSlippage(address aToken) external view returns (uint256);

}

abstract contract AaveFacet_TestBase is Controller_TestBase {

    IControllerLike internal controller;

    function setUp() external {
        controller = IControllerLike(_deploy());

        // NOTE: Only wires the functions needed for the tests.
        //       If more functions are needed in future tests, they should be wired here.
        address facet = address(new AaveFacet());

        vm.label(facet, "AaveFacet");

        vm.startPrank(admin);

        // Controller.setAaveMaxSlippage -> AaveFacet.setMaxSlippage
        controller.setDispatch(
            IControllerLike.setAaveMaxSlippage.selector,
            facet,
            IAaveFacet.setMaxSlippage.selector
        );

        // Controller.getAaveMaxSlippage -> AaveFacet.getMaxSlippage
        controller.setDispatch(
            IControllerLike.getAaveMaxSlippage.selector,
            facet,
            IAaveFacet.getMaxSlippage.selector
        );

        vm.stopPrank();
    }

}

contract Controller_AaveFacet_Admin_Tests is AaveFacet_TestBase {

    function test_setMaxSlippage_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setAaveMaxSlippage(makeAddr("aToken"), 0.98e18);
    }

    function test_setMaxSlippage_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(unauthorized);
        controller.setAaveMaxSlippage(makeAddr("aToken"), 0.98e18);
    }

    function test_setMaxSlippage_aTokenZeroAddress() external {
        vm.expectRevert("AaveFacet/aToken-zero-address");
        vm.prank(admin);
        controller.setAaveMaxSlippage(address(0), 0.98e18);
    }

    function test_setMaxSlippage() external {
        address aToken = makeAddr("aToken");

        assertEq(controller.getAaveMaxSlippage(aToken), 0);

        vm.expectEmit(address(controller));
        emit IAaveFacet.AaveMaxSlippageSet(aToken, 0.98e18);

        vm.prank(admin);
        controller.setAaveMaxSlippage(aToken, 0.98e18);

        assertEq(controller.getAaveMaxSlippage(aToken), 0.98e18);

        vm.record();

        vm.expectEmit(address(controller));
        emit IAaveFacet.AaveMaxSlippageSet(aToken, 0.99e18);

        vm.prank(admin);
        controller.setAaveMaxSlippage(aToken, 0.99e18);

        assertEq(controller.getAaveMaxSlippage(aToken), 0.99e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

}
