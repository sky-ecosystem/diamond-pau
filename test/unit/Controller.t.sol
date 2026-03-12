// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Controller } from "../../src/Controller.sol";

contract ControllerHarness is Controller {

    constructor(address proxy_, address rateLimits_, address accessControls_)
        Controller(proxy_, rateLimits_, accessControls_) {}

    function proxy() public view returns (address) {
        return _getControllerStorage().proxy;
    }

    function rateLimits() public view returns (address) {
        return _getControllerStorage().rateLimits;
    }

    function accessControls() public view returns (address) {
        return _getControllerStorage().accessControls;
    }

}

contract Controller_Tests is Test {

    function test_constructor() external {
        address proxy          = makeAddr("proxy");
        address rateLimits     = makeAddr("rateLimits");
        address accessControls = makeAddr("accessControls");

        ControllerHarness controller = new ControllerHarness(proxy, rateLimits, accessControls);

        assertEq(controller.proxy(),          proxy);
        assertEq(controller.rateLimits(),     rateLimits);
        assertEq(controller.accessControls(), accessControls);
    }

}
