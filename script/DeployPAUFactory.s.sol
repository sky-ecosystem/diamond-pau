// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { PAUFactory } from "../src/PAUFactory.sol";

contract DeployPAUFactory is Script {

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));
        string memory env   = vm.envString("ENV");

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory fileSlug = string(abi.encodePacked("pau-factory-", chain, "-", env));

        console.log("Deploying PAU factory for %s...", chain);

        vm.startBroadcast();

        // Step 1: Deploy PAU factory

        address pauFactory = address(new PAUFactory());

        console.log("PAU factory deployed at: ", pauFactory);

        vm.stopBroadcast();

        // Step 2: Export addresses

        ScriptTools.exportContract(fileSlug, "pauFactory", pauFactory);

    }

}
