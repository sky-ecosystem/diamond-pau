// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { Controller } from "../../src/Controller.sol";

contract ControllerHarness is Controller {

    constructor(
        address proxy_,
        address rateLimits_,
        address accessControlRegistry_,
        address parameterRegistry_
    ) Controller(proxy_, rateLimits_, accessControlRegistry_, parameterRegistry_) {}

    function proxy() public view returns (address) {
        return _getControllerStorage().proxy;
    }

    function rateLimits() public view returns (address) {
        return _getControllerStorage().rateLimits;
    }

    function accessControlRegistry() public view returns (address) {
        return _getControllerStorage().accessControlRegistry;
    }

    function parameterRegistry() public view returns (address) {
        return _getControllerStorage().parameterRegistry;
    }

}

contract Controller_Tests is Test {

    function test_constructor() external {
        address proxy                 = makeAddr("proxy");
        address rateLimits            = makeAddr("rateLimits");
        address accessControlRegistry = makeAddr("accessControlRegistry");
        address parameterRegistry     = makeAddr("parameterRegistry");

        ControllerHarness controller = new ControllerHarness(
            proxy,
            rateLimits,
            accessControlRegistry,
            parameterRegistry
        );

        assertEq(controller.proxy(),                 proxy);
        assertEq(controller.rateLimits(),            rateLimits);
        assertEq(controller.accessControlRegistry(), accessControlRegistry);
        assertEq(controller.parameterRegistry(),     parameterRegistry);
    }

}
