// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { console } from "../lib/forge-std/src/console.sol";

import { Script } from "../lib/forge-std/src/Script.sol";

import { IPAUFactory } from "../src/interfaces/IPAUFactory.sol";
import { IController } from "../src/interfaces/IController.sol";

contract DeployPAU is Script {

    function run(uint256 chainId, address factory, address admin, bytes32 salt) external {
        vm.createSelectFork(getChain(vm.envString("CHAIN")).rpcUrl);

        require(block.chainid == chainId, "DeployPAU/chain-id-mismatch");

        vm.startBroadcast();

        address controller = IPAUFactory(factory).deployPAU(admin, salt);

        vm.stopBroadcast();

        console.log("Controller:     ", controller);
        console.log("ALM Proxy:      ", IController(controller).proxy());
        console.log("Access Controls:", IController(controller).accessControls());
        console.log("Rate Limits:    ", IController(controller).rateLimits());
    }

}
