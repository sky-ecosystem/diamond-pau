// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IERC4626Facet } from "../../../src/interfaces/facets/IERC4626Facet.sol";

import { ERC4626Facet } from "../../../src/libraries/ERC4626Lib.sol";

import { IControllerFull } from "../../interfaces/IControllerFull.sol";

import { ControllerTestBase } from "../ControllerTestBase.t.sol";

contract ERC4626Facet_Base is ControllerTestBase {

    function setUp() public override {
        super.setUp();

        // Wire the ERC4626facet.

        vm.startPrank(admin);

        _wireERC4626Facet();

        vm.stopPrank();
    }

    // NOTE: Only wires the functions needed for the tests.
    //       If more functions are needed in future tests, they should be wired here.
    function _wireERC4626Facet() internal {
        address erc4626Facet = address(new ERC4626Facet());

        vm.label(erc4626Facet, "ERC4626Facet");

        // Controller.setMaxExchangeRate() -> ERC4626Facet.setMaxExchangeRate()
        controller.setFacet(
            IControllerFull.setMaxExchangeRate.selector,
            erc4626Facet,
            IERC4626Facet.setMaxExchangeRate.selector
        );

        // Controller.maxExchangeRates() -> ERC4626Facet.maxExchangeRates()
        controller.setFacet(
            IControllerFull.maxExchangeRates.selector,
            erc4626Facet,
            IERC4626Facet.maxExchangeRates.selector
        );
    }

}

contract ControllerIntegration_ERC4626Facet_SetMaxExchangeRate_Tests is ERC4626Facet_Base {

    // Failure tests

    function test_setMaxExchangeRate_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        controller.setMaxExchangeRate(makeAddr("token"), 1e18, 1e18);
    }

    function test_setMaxExchangeRate_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        controller.setMaxExchangeRate(makeAddr("token"), 1e18, 1e18);
    }

    function test_setMaxExchangeRate_tokenZeroAddress() external {
        vm.expectRevert("ERC4626Facet/token-zero-address");
        vm.prank(admin);
        controller.setMaxExchangeRate(address(0), 1e18, 1e18);
    }

    // Success tests

    function test_setMaxExchangeRate() external {
        address token = makeAddr("token");

        assertEq(controller.maxExchangeRates(token), 0);

        vm.record();

        vm.expectEmit(address(controller));
        emit IERC4626Facet.MaxExchangeRateSet(token, 1e36);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e18, 1e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(controller.maxExchangeRates(token), 1e36);

        vm.expectEmit(address(controller));
        emit IERC4626Facet.MaxExchangeRateSet(token, 1e24);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e18, 1e6);

        assertEq(controller.maxExchangeRates(token), 1e24);

        vm.expectEmit(address(controller));
        emit IERC4626Facet.MaxExchangeRateSet(token, 1e48);

        vm.prank(admin);
        controller.setMaxExchangeRate(token, 1e6, 1e18);

        assertEq(controller.maxExchangeRates(token), 1e48);
    }

}
