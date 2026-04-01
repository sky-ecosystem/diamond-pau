// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, stdJson, console } from "../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../lib/dss-test/src/ScriptTools.sol";

import { AccessControls } from "../src/AccessControls.sol";
import { ALMProxy }       from "../src/ALMProxy.sol";
import { Controller }     from "../src/Controller.sol";
import { PAUFactory }     from "../src/PAUFactory.sol";
import { RateLimits }     from "../src/RateLimits.sol";

contract DeployPAU is Script {

    using stdJson for string;

    function run() external {
        string memory chain = vm.envOr("CHAIN", string("mainnet"));
        string memory env   = vm.envString("ENV");
        string memory star  = vm.envString("STAR");

        vm.createSelectFork(getChain(chain).rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory fileSlug = string(abi.encodePacked(star, "-pau-", chain, "-", env));
        string memory config   = ScriptTools.loadConfig(fileSlug);

        address admin      = config.readAddress(".admin");
        address freezer    = config.readAddress(".freezer");
        address pauFactory = config.readAddress(".pauFactory");
        address relayer    = config.readAddress(".relayer");

        console.log("Deploying PAU system for %s...", chain);

        vm.startBroadcast();

        address deployer = msg.sender;

        require(deployer != admin, "DeployPAU/deployer-must-differ-from-admin");

        // Step 1: Deploy PAU system with deployer as temporary admin

        Controller controller = Controller(payable(PAUFactory(pauFactory).deploy(deployer)));

        console.log("Controller deployed at: ", address(controller));

        AccessControls accessControls = AccessControls(controller.accessControls());
        ALMProxy almProxy             = ALMProxy(payable(controller.proxy()));
        RateLimits rateLimits         = RateLimits(controller.rateLimits());

        // Step 2: Grant roles to relayer and freezer on AccessControls

        accessControls.grantRole(accessControls.RELAYER_ROLE(), relayer);
        accessControls.grantRole(accessControls.FREEZER_ROLE(), freezer);

        // Step 3: Transfer DEFAULT_ADMIN_ROLE to final admin and revoke from deployer.
        //         For AccessControls, ALMProxy, and RateLimits.

        accessControls.grantRole(accessControls.DEFAULT_ADMIN_ROLE(), admin);
        almProxy.grantRole(almProxy.DEFAULT_ADMIN_ROLE(),             admin);
        rateLimits.grantRole(rateLimits.DEFAULT_ADMIN_ROLE(),         admin);

        accessControls.revokeRole(accessControls.DEFAULT_ADMIN_ROLE(), deployer);
        almProxy.revokeRole(almProxy.DEFAULT_ADMIN_ROLE(),             deployer);
        rateLimits.revokeRole(rateLimits.DEFAULT_ADMIN_ROLE(),         deployer);

        console.log("Admin transferred to: ", admin);

        vm.stopBroadcast();

        // Step 4: Export addresses

        ScriptTools.exportContract(fileSlug, "accessControls", address(accessControls));
        ScriptTools.exportContract(fileSlug, "almProxy",       address(almProxy));
        ScriptTools.exportContract(fileSlug, "controller",     address(controller));
        ScriptTools.exportContract(fileSlug, "rateLimits",     address(rateLimits));

    }

}
