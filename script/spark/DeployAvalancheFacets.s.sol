// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Avalanche } from "../../lib/spark-address-registry/src/Avalanche.sol";

import { AaveFacet }       from "../../src/facets/aave/AaveFacet.sol";
import { CCTPFacet }       from "../../src/facets/cctp/CCTPFacet.sol";
import { SparkVaultFacet } from "../../src/facets/spark-vault/SparkVaultFacet.sol";

contract DeployAvalancheFacets is Script {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    // NOTE: Struct to hold Avalanche facet deployment addresses.
    struct AvalancheFacetAddresses {
        address aaveFacet;
        address cctpFacet;
        address sparkVaultFacet;
    }

    /**********************************************************************************************/
    /*** Run function                                                                           ***/
    /**********************************************************************************************/

    function run() external {
        vm.createSelectFork(getChain("avalanche").rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("spark-facets-avalanche-", env));

        console.log("Deploying PAU facets for Spark\n  Chain: Avalanche\n  Env: %s", env);

        vm.startBroadcast();

        // Step 1: Deploy facets.
        AvalancheFacetAddresses memory facets = _deployFacets();

        vm.stopBroadcast();

        // Step 2: Export facet addresses.
        _exportFacets(facets, fileSlug);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _deployFacets() internal returns (AvalancheFacetAddresses memory facets) {
        facets.aaveFacet = address(new AaveFacet());

        facets.cctpFacet = address(new CCTPFacet(
            Avalanche.CCTP_TOKEN_MESSENGER,
            Avalanche.USDC
        ));

        facets.sparkVaultFacet = address(new SparkVaultFacet());
    }

    function _exportFacets(AvalancheFacetAddresses memory facets, string memory fileSlug) internal {
        ScriptTools.exportContract(fileSlug, "aaveFacet",       facets.aaveFacet);
        ScriptTools.exportContract(fileSlug, "cctpFacet",       facets.cctpFacet);
        ScriptTools.exportContract(fileSlug, "sparkVaultFacet", facets.sparkVaultFacet);
    }

}
