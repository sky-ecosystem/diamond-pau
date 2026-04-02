// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Arbitrum } from "../../lib/spark-address-registry/src/Arbitrum.sol";

import { AaveFacet }    from "../../src/facets/aave/AaveFacet.sol";
import { CCTPFacet }    from "../../src/facets/cctp/CCTPFacet.sol";
import { ERC4626Facet } from "../../src/facets/erc4626/ERC4626Facet.sol";
import { PSM3Facet }    from "../../src/facets/psm3/PSM3Facet.sol";

contract DeployArbitrumFacets is Script {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    // NOTE: Struct to hold Arbitrum facet deployment addresses.
    struct ArbitrumFacetAddresses {
        address aaveFacet;
        address cctpFacet;
        address erc4626Facet;
        address psm3Facet;
    }

    /**********************************************************************************************/
    /*** Run function                                                                           ***/
    /**********************************************************************************************/

    function run() external {
        vm.createSelectFork(getChain("arbitrum_one").rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("spark-facets-arbitrum_one-", env));

        console.log("Deploying PAU facets for Spark\n  Chain: Arbitrum\n  Env: %s", env);

        vm.startBroadcast();

        // Step 1: Deploy facets.
        ArbitrumFacetAddresses memory facets = _deployFacets();

        vm.stopBroadcast();

        // Step 2: Export facet addresses.
        _exportFacets(facets, fileSlug);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _deployFacets() internal returns (ArbitrumFacetAddresses memory facets) {
        facets.aaveFacet = address(new AaveFacet());

        facets.cctpFacet = address(new CCTPFacet(
            Arbitrum.CCTP_TOKEN_MESSENGER,
            Arbitrum.USDC
        ));

        facets.erc4626Facet = address(new ERC4626Facet());

        facets.psm3Facet = address(new PSM3Facet(Arbitrum.PSM3));
    }

    function _exportFacets(ArbitrumFacetAddresses memory facets, string memory fileSlug) internal {
        ScriptTools.exportContract(fileSlug, "aaveFacet",    facets.aaveFacet);
        ScriptTools.exportContract(fileSlug, "cctpFacet",    facets.cctpFacet);
        ScriptTools.exportContract(fileSlug, "erc4626Facet", facets.erc4626Facet);
        ScriptTools.exportContract(fileSlug, "psm3Facet",    facets.psm3Facet);
    }

}
