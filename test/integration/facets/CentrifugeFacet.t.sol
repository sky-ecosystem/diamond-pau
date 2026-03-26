// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ICentrifugeFacet } from "../../../src/interfaces/facets/ICentrifugeFacet.sol";
import { IController }      from "../../../src/interfaces/IController.sol";

import { CentrifugeFacet } from "../../../src/libraries/CentrifugeLib.sol";

import { ControllerTestBase } from "../ControllerTestBase.t.sol";

interface IControllerLike is IController {

    function setCentrifugeRecipient(uint16 centrifugeId, bytes32 recipient) external;

    function centrifugeRecipients(uint16 centrifugeId) external view returns (bytes32);

}

contract CentrifugeFacet_Base is ControllerTestBase {

    IControllerLike internal controller;

    bytes32 internal centrifugeRecipient1 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient1"))));
    bytes32 internal centrifugeRecipient2 = bytes32(uint256(uint160(makeAddr("centrifugeRecipient2"))));

    function setUp() public override {
        super.setUp();

        controller = IControllerLike(controllerAddress);

        // Wire the CentrifugeFacet.

        vm.startPrank(admin);

        _wireCentrifugeFacet();

        vm.stopPrank();
    }

    // NOTE: Only wires the functions needed for the tests.
    //       If more functions are needed in future tests, they should be wired here.
    function _wireCentrifugeFacet() internal {
        address centrifugeFacet = address(new CentrifugeFacet());

        vm.label(centrifugeFacet, "CentrifugeFacet");

        // Controller.setCentrifugeRecipient() -> CentrifugeFacet.setCentrifugeRecipient()
        controller.setDispatch(
            IControllerLike.setCentrifugeRecipient.selector,
            centrifugeFacet,
            ICentrifugeFacet.setCentrifugeRecipient.selector
        );

        // Controller.centrifugeRecipients() -> CentrifugeFacet.centrifugeRecipients()
        controller.setDispatch(
            IControllerLike.centrifugeRecipients.selector,
            centrifugeFacet,
            ICentrifugeFacet.centrifugeRecipients.selector
        );
    }

}


contract MainnetController_Admin_SetCentrifugeRecipient_Tests is CentrifugeFacet_Base {

    function test_setCentrifugeRecipient_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);
    }

    function test_setCentrifugeRecipient() external {
        assertEq(controller.centrifugeRecipients(1), bytes32(0));
        assertEq(controller.centrifugeRecipients(2), bytes32(0));

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(1, centrifugeRecipient1);

        vm.prank(admin);
        controller.setCentrifugeRecipient(1, centrifugeRecipient1);

        assertEq(controller.centrifugeRecipients(1), centrifugeRecipient1);

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(2, centrifugeRecipient2);

        vm.prank(admin);
        controller.setCentrifugeRecipient(2, centrifugeRecipient2);

        assertEq(controller.centrifugeRecipients(2), centrifugeRecipient2);

        vm.record();

        vm.expectEmit(address(controller));
        emit ICentrifugeFacet.CentrifugeRecipientSet(1, centrifugeRecipient2);

        vm.prank(admin);
        controller.setCentrifugeRecipient(1, centrifugeRecipient2);

        assertEq(controller.centrifugeRecipients(1), centrifugeRecipient2);

        _assertReentrancyGuardWrittenToTwice();
    }

}
