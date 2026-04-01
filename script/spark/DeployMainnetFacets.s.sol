// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Script, console } from "../../lib/forge-std/src/Script.sol";

import { ScriptTools } from "../../lib/dss-test/src/ScriptTools.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { AaveFacet }          from "../../src/facets/aave/AaveFacet.sol";
import { CCTPFacet }          from "../../src/facets/cctp/CCTPFacet.sol";
import { CurveFacet }         from "../../src/facets/curve/CurveFacet.sol";
import { DAIUSDSFacet }       from "../../src/facets/dai-usds/DAIUSDSFacet.sol";
import { ERC4626Facet }       from "../../src/facets/erc4626/ERC4626Facet.sol";
import { FarmFacet }          from "../../src/facets/farm/FarmFacet.sol";
import { LayerZeroFacet }     from "../../src/facets/layer-zero/LayerZeroFacet.sol";
import { MapleFacet }         from "../../src/facets/maple/MapleFacet.sol";
import { OTCFacet }           from "../../src/facets/otc/OTCFacet.sol";
import { PSMFacet }           from "../../src/facets/psm/PSMFacet.sol";
import { SparkVaultFacet }    from "../../src/facets/spark-vault/SparkVaultFacet.sol";
import { SuperstateFacet }    from "../../src/facets/superstate/SuperstateFacet.sol";
import { TransferAssetFacet } from "../../src/facets/transfer-asset/TransferAssetFacet.sol";
import { UniswapV4Facet }     from "../../src/facets/uniswap-v4/UniswapV4Facet.sol";
import { USDEFacet }          from "../../src/facets/usde/USDEFacet.sol";
import { USDSFacet }          from "../../src/facets/usds/USDSFacet.sol";

contract DeployMainnetFacets is Script {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct MainnetFacetAddresses { // @TODO : Re-check all the integrations in mainnet. Remove unused ones and add any missing ones.
        address aaveFacet;
        address cctpFacet;
        address curveFacet;
        address daiUsdsFacet;
        address erc4626Facet;
        address farmFacet;
        address layerZeroFacet;
        address mapleFacet;
        address otcFacet;
        address psmFacet;
        address sparkVaultFacet;
        address superstateFacet;
        address transferAssetFacet;
        address uniswapV4Facet;
        address usdeFacet;
        address usdsFacet;
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    // NOTE: From https://docs.uniswap.org/contracts/v4/deployments (Ethereum Mainnet).
    address internal constant _PERMIT2                     = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant _UNISWAP_V4_POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address internal constant _UNISWAP_V4_ROUTER           = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;

    /**********************************************************************************************/
    /*** Run function                                                                           ***/
    /**********************************************************************************************/

    function run() external {
        vm.createSelectFork(getChain("mainnet").rpcUrl);

        vm.setEnv("FOUNDRY_ROOT_CHAINID",             vm.toString(block.chainid));
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory env      = vm.envString("ENV");
        string memory fileSlug = string(abi.encodePacked("spark-facets-mainnet-", env));

        console.log("Deploying PAU facets for Ethereum Mainnet...");

        vm.startBroadcast();

        // Step 1: Deploy facets.
        MainnetFacetAddresses memory facets = _deployFacets();

        vm.stopBroadcast();

        // Step 2: Export facet addresses.
        _exportFacets(facets, fileSlug);
    }

    function _deployFacets() internal returns (MainnetFacetAddresses memory facets) {
        facets.aaveFacet = address(new AaveFacet());

        facets.cctpFacet = address(new CCTPFacet(
            Ethereum.CCTP_TOKEN_MESSENGER,
            Ethereum.USDC
        ));

        facets.curveFacet = address(new CurveFacet());

        facets.daiUsdsFacet = address(new DAIUSDSFacet({
            dai_     : Ethereum.DAI,
            daiUSDS_ : Ethereum.DAI_USDS,
            usds_    : Ethereum.USDS
        }));

        facets.erc4626Facet = address(new ERC4626Facet());

        facets.farmFacet = address(new FarmFacet());

        facets.layerZeroFacet = address(new LayerZeroFacet());

        facets.mapleFacet = address(new MapleFacet());
    
        facets.otcFacet = address(new OTCFacet());

        facets.psmFacet = address(new PSMFacet(
            Ethereum.DAI,
            Ethereum.DAI_USDS,
            Ethereum.PSM,
            Ethereum.USDC,
            Ethereum.USDS
        ));

        facets.sparkVaultFacet = address(new SparkVaultFacet());

        facets.superstateFacet = address(new SuperstateFacet(
            Ethereum.USDC,
            Ethereum.USTB
        ));

        facets.transferAssetFacet = address(new TransferAssetFacet());

        facets.uniswapV4Facet = address(new UniswapV4Facet({
            permit2_         : _PERMIT2,
            positionManager_ : _UNISWAP_V4_POSITION_MANAGER,
            router_          : _UNISWAP_V4_ROUTER
        }));

        facets.usdeFacet = address(new USDEFacet(
            Ethereum.ETHENA_MINTER,
            Ethereum.SUSDE,
            Ethereum.USDC,
            Ethereum.USDE
        ));

        facets.usdsFacet = address(new USDSFacet(Ethereum.ALLOCATOR_VAULT, Ethereum.USDS));
    }

    function _exportFacets(MainnetFacetAddresses memory facets, string memory fileSlug) internal {
        ScriptTools.exportContract(fileSlug, "aaveFacet",          facets.aaveFacet);
        ScriptTools.exportContract(fileSlug, "cctpFacet",          facets.cctpFacet);
        ScriptTools.exportContract(fileSlug, "curveFacet",         facets.curveFacet);
        ScriptTools.exportContract(fileSlug, "daiUsdsFacet",       facets.daiUsdsFacet);
        ScriptTools.exportContract(fileSlug, "erc4626Facet",       facets.erc4626Facet);
        ScriptTools.exportContract(fileSlug, "farmFacet",          facets.farmFacet);
        ScriptTools.exportContract(fileSlug, "layerZeroFacet",     facets.layerZeroFacet);
        ScriptTools.exportContract(fileSlug, "mapleFacet",         facets.mapleFacet);
        ScriptTools.exportContract(fileSlug, "otcFacet",           facets.otcFacet);
        ScriptTools.exportContract(fileSlug, "psmFacet",           facets.psmFacet);
        ScriptTools.exportContract(fileSlug, "sparkVaultFacet",    facets.sparkVaultFacet);
        ScriptTools.exportContract(fileSlug, "superstateFacet",    facets.superstateFacet);
        ScriptTools.exportContract(fileSlug, "transferAssetFacet", facets.transferAssetFacet);
        ScriptTools.exportContract(fileSlug, "uniswapV4Facet",     facets.uniswapV4Facet);
        ScriptTools.exportContract(fileSlug, "usdeFacet",          facets.usdeFacet);
        ScriptTools.exportContract(fileSlug, "usdsFacet",          facets.usdsFacet);
    }

}
