// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICCTPFacet }  from "../../../src/interfaces/facets/ICCTPFacet.sol";
import { IController } from "../../../src/interfaces/IController.sol";

import { CCTPFacet } from "../../../src/libraries/CCTPLib.sol";

import { ControllerTestBase } from "../ControllerTestBase.t.sol";

interface IControllerLike is IController {

    function cctpMaxFeeCap() external view returns (uint256);

    function mintRecipients(uint32 destinationDomain) external view returns (bytes32);

    function setCCTPMaxFeeCap(uint256 maxFeeCap) external;

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

}

contract CCTPFacet_Base is ControllerTestBase {

    IControllerLike internal controller;

    bytes32 internal mintRecipient1 = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 internal mintRecipient2 = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));

    function setUp() public override {
        super.setUp();

        controller = IControllerLike(controllerAddress);

        // Wire the CCTP facet.

        vm.startPrank(admin);

        _wireCCTPFacet();

        vm.stopPrank();
    }

    // NOTE: Only wires the functions needed for the tests.
    //       If more functions are needed in future tests, they should be wired here.
    function _wireCCTPFacet() internal {
        address cctpFacet = address(new CCTPFacet(makeAddr("cctp"), makeAddr("usdc")));

        vm.label(cctpFacet, "CCTPFacet");

        // Controller.cctpMaxFeeCap() -> CCTPFacet.cctpMaxFeeCap()
        controller.setDispatch(
            IControllerLike.cctpMaxFeeCap.selector,
            cctpFacet,
            ICCTPFacet.cctpMaxFeeCap.selector
        );

        // Controller.mintRecipients() -> CCTPFacet.mintRecipients()
        controller.setDispatch(
            IControllerLike.mintRecipients.selector,
            cctpFacet,
            ICCTPFacet.mintRecipients.selector
        );

        // Controller.setCCTPMaxFeeCap() -> CCTPFacet.setCCTPMaxFeeCap()
        controller.setDispatch(
            IControllerLike.setCCTPMaxFeeCap.selector,
            cctpFacet,
            ICCTPFacet.setCCTPMaxFeeCap.selector
        );

        // Controller.setMintRecipient() -> CCTPFacet.setMintRecipient()
        controller.setDispatch(
            IControllerLike.setMintRecipient.selector,
            cctpFacet,
            ICCTPFacet.setMintRecipient.selector
        );
    }

}

contract ControllerIntegration_CCTPFacet_SetCCTPMaxFeeCap_Tests is CCTPFacet_Base {

    function test_setCCTPMaxFeeCap_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setCCTPMaxFeeCap(1e18);
    }

    function test_setCCTPMaxFeeCap_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setCCTPMaxFeeCap(1e18);
    }

    function test_setCCTPMaxFeeCap() external {
        assertEq(controller.cctpMaxFeeCap(), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICCTPFacet.CCTPMaxFeeCapSet(1e18);

        vm.prank(admin);
        controller.setCCTPMaxFeeCap(1e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(controller.cctpMaxFeeCap(), 1e18);
    }

}

contract ControllerIntegration_CCTPFacet_SetMintRecipient_Tests is CCTPFacet_Base {

    function test_setMintRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient() external {
        assertEq(controller.mintRecipients(1), bytes32(0));
        assertEq(controller.mintRecipients(2), bytes32(0));

        vm.expectEmit(address(controller));
        emit ICCTPFacet.MintRecipientSet(1, mintRecipient1);

        vm.prank(admin);
        controller.setMintRecipient(1, mintRecipient1);

        assertEq(controller.mintRecipients(1), mintRecipient1);

        vm.expectEmit(address(controller));
        emit ICCTPFacet.MintRecipientSet(2, mintRecipient2);

        vm.prank(admin);
        controller.setMintRecipient(2, mintRecipient2);

        assertEq(controller.mintRecipients(2), mintRecipient2);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICCTPFacet.MintRecipientSet(1, mintRecipient2);

        vm.prank(admin);
        controller.setMintRecipient(1, mintRecipient2);

        assertEq(controller.mintRecipients(1), mintRecipient2);

        _assertReentrancyGuardWrittenToTwice();
    }

}
