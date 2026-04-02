// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { PAUFactory } from "../src/PAUFactory.sol";

contract DeployPAUFactory is Script {

    using stdJson for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));
        string memory env   = vm.envString("ENV");

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory fileSlug = string(abi.encodePacked("pau-factory-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        address admin          = config.readAddress(".admin");
        address facetValidator = config.readAddress(".facetValidator");

        console.log("Deploying PAU factory...\n  Chain: %s\n  Env: %s", chain, env);

        vm.startBroadcast();

        // Step 1: Deploy PAU factory

        address pauFactory = address(new PAUFactory(admin, facetValidator));

        console.log("PAU factory deployed at: ", pauFactory);

        vm.stopBroadcast();

        // Step 2: Export addresses

        ScriptTools.exportContract(fileSlug, "pauFactory", pauFactory);

    }

}
