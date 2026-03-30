// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICCTPFacet } from "../../../src/facets/cctp/ICCTPFacet.sol";
import { CCTPFacet }  from "../../../src/facets/cctp/CCTPFacet.sol";

import { Controller_TestBase } from "../TestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IControllerLike {

    function setDispatch(bytes4 callSelector, address facet, bytes4 delegateSelector) external;

    function setMaxFeeCap(uint256 maxFeeCap) external;

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

    function maxFeeCap() external view returns (uint256);

    function getMintRecipient(uint32 destinationDomain) external view returns (bytes32);

}

abstract contract CCTPFacet_TestBase is Controller_TestBase {

    IControllerLike internal controller;

    bytes32 internal mintRecipient1 = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 internal mintRecipient2 = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));

    function setUp() external {
        controller = IControllerLike(_deploy());

        // NOTE: Only wires the functions needed for the tests.
        //       If more functions are needed in future tests, they should be wired here.
        address facet = address(new CCTPFacet(makeAddr("cctp"), makeAddr("usdc")));

        vm.label(facet, "CCTPFacet");

        vm.startPrank(admin);

        // Controller.maxFeeCap -> CCTPFacet.maxFeeCap
        controller.setDispatch(
            IControllerLike.maxFeeCap.selector,
            facet,
            ICCTPFacet.maxFeeCap.selector
        );

        // Controller.getMintRecipient -> CCTPFacet.getMintRecipient
        controller.setDispatch(
            IControllerLike.getMintRecipient.selector,
            facet,
            ICCTPFacet.getMintRecipient.selector
        );

        // Controller.setMaxFeeCap -> CCTPFacet.setMaxFeeCap
        controller.setDispatch(
            IControllerLike.setMaxFeeCap.selector,
            facet,
            ICCTPFacet.setMaxFeeCap.selector
        );

        // Controller.setMintRecipient -> CCTPFacet.setMintRecipient
        controller.setDispatch(
            IControllerLike.setMintRecipient.selector,
            facet,
            ICCTPFacet.setMintRecipient.selector
        );

        vm.stopPrank();
    }

}

contract Controller_CCTPFacet_SetMaxFeeCap_Tests is CCTPFacet_TestBase {

    function test_setMaxFeeCap_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxFeeCap(1e18);
    }

    function test_setMaxFeeCap_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setMaxFeeCap(1e18);
    }

    function test_setMaxFeeCap() external {
        assertEq(controller.maxFeeCap(), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICCTPFacet.CCTPMaxFeeCapSet(1e18);

        vm.prank(admin);
        controller.setMaxFeeCap(1e18);

        _assertReentrancyGuardWrittenToTwice(address(controller));

        assertEq(controller.maxFeeCap(), 1e18);
    }

}

contract Controller_CCTPFacet_SetMintRecipient_Tests is CCTPFacet_TestBase {

    function test_SetMintRecipient_reentrancy() external {
        _setEntered(address(controller));
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMintRecipient(1, mintRecipient1);
    }

    function test_SetMintRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));
        vm.prank(unauthorized);
        controller.setMintRecipient(1, mintRecipient1);
    }

    function test_SetMintRecipient() external {
        assertEq(controller.getMintRecipient(1), bytes32(0));
        assertEq(controller.getMintRecipient(2), bytes32(0));

        vm.expectEmit(address(controller));
        emit ICCTPFacet.CCTPMintRecipientSet(1, mintRecipient1);

        vm.prank(admin);
        controller.setMintRecipient(1, mintRecipient1);

        assertEq(controller.getMintRecipient(1), mintRecipient1);

        vm.expectEmit(address(controller));
        emit ICCTPFacet.CCTPMintRecipientSet(2, mintRecipient2);

        vm.prank(admin);
        controller.setMintRecipient(2, mintRecipient2);

        assertEq(controller.getMintRecipient(2), mintRecipient2);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICCTPFacet.CCTPMintRecipientSet(1, mintRecipient2);

        vm.prank(admin);
        controller.setMintRecipient(1, mintRecipient2);

        assertEq(controller.getMintRecipient(1), mintRecipient2);

        _assertReentrancyGuardWrittenToTwice(address(controller));
    }

}
