// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Base } from "../../lib/spark-address-registry/src/Base.sol";

import { AaveFacet }          from "../../src/facets/aave/AaveFacet.sol";
import { CCTPFacet }          from "../../src/facets/cctp/CCTPFacet.sol";
import { TransferAssetFacet } from "../../src/facets/transfer-asset/TransferAssetFacet.sol";

contract DeployBaseFacets is Script {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct BaseFacetAddresses { // @TODO : Re-check all the integrations in base. Remove unused ones and add any missing ones.
        address aaveFacet;
        address cctpFacet;
        address transferAssetFacet;
    }

    /**********************************************************************************************/
    /*** Run function                                                                           ***/
    /**********************************************************************************************/

    function run() external {
        vm.createSelectFork(getChain("base").rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("spark-facets-base-", env));

        console.log("Deploying PAU facets for Base...");

        vm.startBroadcast();

        // Step 1: Deploy facets.
        BaseFacetAddresses memory facets = _deployFacets();

        vm.stopBroadcast();

        // Step 2: Export facet addresses.
        _exportFacets(facets, fileSlug);
    }

    function _deployFacets() internal returns (BaseFacetAddresses memory facets) {
        facets.aaveFacet = address(new AaveFacet());

        facets.cctpFacet = address(new CCTPFacet(
            Base.CCTP_TOKEN_MESSENGER,
            Base.USDC
        ));

        facets.transferAssetFacet = address(new TransferAssetFacet());
    }

    function _exportFacets(BaseFacetAddresses memory facets, string memory fileSlug) internal {
        ScriptTools.exportContract(fileSlug, "aaveFacet",          facets.aaveFacet);
        ScriptTools.exportContract(fileSlug, "cctpFacet",          facets.cctpFacet);
        ScriptTools.exportContract(fileSlug, "transferAssetFacet", facets.transferAssetFacet);
    }

}
