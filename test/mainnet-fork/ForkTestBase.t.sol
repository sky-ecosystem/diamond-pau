// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { AllocatorDeploy } from "../../lib/dss-allocator/deploy/AllocatorDeploy.sol";

import { AllocatorInit, AllocatorIlkConfig } from "../../lib/dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "../../lib/dss-allocator/deploy/AllocatorInstances.sol";

import { DssTest }          from "../../lib/dss-test/src/DssTest.sol";
import { DssInstance, MCD } from "../../lib/dss-test/src/MCD.sol";

import { IERC20 }   from "../../lib/forge-std/src/interfaces/IERC20.sol";
import { IERC4626 } from "../../lib/forge-std/src/interfaces/IERC4626.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Ethereum as GroveEthereum } from "../../lib/grove-address-registry/src/Ethereum.sol";

import { DomainHelpers } from "../../lib/xchain-helpers/src/testing/Domain.sol";

import { AaveFacet }          from "../../src/facets/aave/AaveFacet.sol";
import { AaveV4Facet }        from "../../src/facets/aave-v4/AaveV4Facet.sol";
import { BasinFacet }         from "../../src/facets/basin/BasinFacet.sol";
import { CCTPFacet }          from "../../src/facets/cctp/CCTPFacet.sol";
import { CentrifugeFacet }    from "../../src/facets/centrifuge/CentrifugeFacet.sol";
import { CurveFacet }         from "../../src/facets/curve/CurveFacet.sol";
import { DAIUSDSFacet }       from "../../src/facets/dai-usds/DAIUSDSFacet.sol";
import { DualPoolFacet }      from "../../src/facets/dual-pool/DualPoolFacet.sol";
import { ERC4626Facet }       from "../../src/facets/erc4626/ERC4626Facet.sol";
import { ERC7540Facet }       from "../../src/facets/erc7540/ERC7540Facet.sol";
import { EthenaFacet }        from "../../src/facets/ethena/EthenaFacet.sol";
import { FarmFacet }          from "../../src/facets/farm/FarmFacet.sol";
import { LayerZeroFacet }     from "../../src/facets/layer-zero/LayerZeroFacet.sol";
import { MapleFacet }         from "../../src/facets/maple/MapleFacet.sol";
import { MerklFacet }         from "../../src/facets/merkl/MerklFacet.sol";
import { NFATHaloFacet }      from "../../src/facets/nfat-halo/NFATHaloFacet.sol";
import { NFATPrimeFacet }     from "../../src/facets/nfat-prime/NFATPrimeFacet.sol";
import { OTCFacet }           from "../../src/facets/otc/OTCFacet.sol";
import { PendleFacet }        from "../../src/facets/pendle/PendleFacet.sol";
import { PSMFacet }           from "../../src/facets/psm/PSMFacet.sol";
import { SparkVaultFacet }    from "../../src/facets/spark-vault/SparkVaultFacet.sol";
import { SuperstateFacet }    from "../../src/facets/superstate/SuperstateFacet.sol";
import { TransferAssetFacet } from "../../src/facets/transfer-asset/TransferAssetFacet.sol";
import { UniswapV3Facet }     from "../../src/facets/uniswap-v3/UniswapV3Facet.sol";
import { UniswapV4Facet }     from "../../src/facets/uniswap-v4/UniswapV4Facet.sol";
import { USDSFacet }          from "../../src/facets/usds/USDSFacet.sol";
import { WEETHFacet }         from "../../src/facets/weeth/WEETHFacet.sol";
import { WrapProxyETHFacet }  from "../../src/facets/wrap-proxy-eth/WrapProxyETHFacet.sol";
import { WSTETHFacet }        from "../../src/facets/wsteth/WSTETHFacet.sol";

import { IAccessControls } from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../../src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";

import { BeaconConfig } from "../../src/libraries/BeaconConfig.sol";

import { Beacon }     from "../../src/Beacon.sol";
import { PAUFactory } from "../../src/PAUFactory.sol";

import { IMainnetControllerFull } from "../interfaces/IMainnetControllerFull.sol";

interface IChainlogLike {

    function getAddress(bytes32) external view returns (address);

}

interface IBufferLike {

    function approve(address, address, uint256) external;

}

interface IPSMLike {

    function kiss(address) external;

}

interface ISUSDELike is IERC4626 {

    function cooldownAssets(uint256 usdeAmount) external returns (uint256);

    function cooldownShares(uint256 susdeAmount) external returns (uint256);

    function unstake(address receiver) external;

    function silo() external view returns (address);

}

interface IVaultLike {

    function buffer() external view returns (address);

    function rely(address) external;

}

abstract contract ForkTestBase is DssTest {

    using DomainHelpers for *;

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    address internal constant UNISWAP_V3_ROUTER           = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant UNISWAP_V3_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _REENTRANCY_GUARD_SLOT        = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;
    bytes32 internal constant _REENTRANCY_GUARD_NOT_ENTERED = bytes32(uint256(1));
    bytes32 internal constant _REENTRANCY_GUARD_ENTERED     = bytes32(uint256(2));

    bytes32 constant ilk = "ILK-A";

    bytes32 constant ALLOCATOR_ROLE       = keccak256("ALLOCATOR_ROLE");
    bytes32 constant ALLOCATOR_ADMIN_ROLE = keccak256("ALLOCATOR_ADMIN_ROLE");
    bytes32 constant DEFAULT_ADMIN_ROLE   = 0x00;

    bytes32 constant PSM_ILK = 0x4c4954452d50534d2d555344432d410000000000000000000000000000000000;

    uint256 constant INK           = 1e12 * 1e18;  // Ink initialization amount
    uint256 constant SEVEN_PCT_APY = 1.000000002145441671308778766e27;  // 7% APY (current DSR)
    uint256 constant EIGHT_PCT_APY = 1.000000002440418608258400030e27;  // 8% APY (current DSR + 1%)

    // NOTE: From https://docs.uniswap.org/contracts/v4/deployments (Ethereum Mainnet).
    address internal constant _PERMIT2                     = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address internal constant _UNISWAP_V4_POOL_MANAGER     = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address internal constant _UNISWAP_V4_POSITION_MANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address internal constant _UNISWAP_V4_ROUTER           = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;

    address allocator      = Ethereum.ALM_RELAYER_MULTISIG;
    address allocatorAdmin = Ethereum.ALM_FREEZER_MULTISIG;

    address backstopAllocator = makeAddr("backstopAllocator");  // TODO: Replace with real backstop

    /**********************************************************************************************/
    /*** Mainnet addresses/constants                                                            ***/
    /**********************************************************************************************/

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address constant CCTP_MESSENGER = Ethereum.CCTP_TOKEN_MESSENGER;
    address constant DAI_USDS       = Ethereum.DAI_USDS;
    address constant ETHENA_MINTER  = Ethereum.ETHENA_MINTER;
    address constant PAUSE_PROXY    = Ethereum.PAUSE_PROXY;
    address constant SPARK_PROXY    = Ethereum.SPARK_PROXY;

    IERC20 constant dai  = IERC20(Ethereum.DAI);
    IERC20 constant usdc = IERC20(Ethereum.USDC);
    IERC20 constant usde = IERC20(Ethereum.USDE);
    IERC20 constant usds = IERC20(Ethereum.USDS);
    IERC20 constant usdt = IERC20(Ethereum.USDT);

    IERC4626 constant susds = IERC4626(Ethereum.SUSDS);

    ISUSDELike constant susde = ISUSDELike(Ethereum.SUSDE);

    address POCKET;
    address USDS_JOIN;

    DssInstance dss;  // Mainnet DSS

    /**********************************************************************************************/
    /*** ALM system and allocation system deployments                                           ***/
    /**********************************************************************************************/

    Beacon                 beacon;
    IAccessControls        accessControls;
    IALMProxy              almProxy;
    IMainnetControllerFull mainnetController;
    IRateLimits            rateLimits;
    PAUFactory             factory;

    address buffer;
    address vault;

    /**********************************************************************************************/
    /*** Cached mainnet state variables                                                         ***/
    /**********************************************************************************************/

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;
    uint256 USDS_SUPPLY;
    uint256 USDS_BAL_SUSDS;
    uint256 VAT_DAI_USDS_JOIN;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {

        /*** Step 1: Set up environment, cast addresses ***/

        getChain("mainnet").createSelectFork(_getBlock());

        dss = MCD.loadFromChainlog(LOG);

        USDS_JOIN = IChainlogLike(LOG).getAddress("USDS_JOIN");
        POCKET    = IChainlogLike(LOG).getAddress("MCD_LITE_PSM_USDC_A_POCKET");

        DAI_BAL_PSM       = dai.balanceOf(Ethereum.PSM);
        DAI_SUPPLY        = dai.totalSupply();
        USDC_BAL_PSM      = usdc.balanceOf(POCKET);
        USDC_SUPPLY       = usdc.totalSupply();
        USDS_SUPPLY       = usds.totalSupply();
        USDS_BAL_SUSDS    = usds.balanceOf(Ethereum.SUSDS);
        VAT_DAI_USDS_JOIN = dss.vat.dai(USDS_JOIN);

        /*** Step 2: Deploy and configure allocation system ***/

        AllocatorSharedInstance memory sharedInst
            = AllocatorDeploy.deployShared(address(this), Ethereum.PAUSE_PROXY);

        AllocatorIlkInstance memory ilkInst = AllocatorDeploy.deployIlk({
            deployer : address(this),
            owner    : Ethereum.PAUSE_PROXY,
            roles    : sharedInst.roles,
            ilk      : ilk,
            usdsJoin : USDS_JOIN
        });

        AllocatorIlkConfig memory ilkConfig = AllocatorIlkConfig({
            ilk            : ilk,
            duty           : EIGHT_PCT_APY,
            maxLine        : 100_000_000 * RAD,
            gap            : 10_000_000 * RAD,
            ttl            : 6 hours,
            allocatorProxy : Ethereum.SPARK_PROXY,
            ilkRegistry    : IChainlogLike(LOG).getAddress("ILK_REGISTRY")
        });

        vm.startPrank(Ethereum.PAUSE_PROXY);
        AllocatorInit.initShared(dss, sharedInst);
        AllocatorInit.initIlk(dss, sharedInst, ilkInst, ilkConfig);
        vm.stopPrank();

        buffer = ilkInst.buffer;
        vault  = ilkInst.vault;

        /*** Step 3: Deploy ALM system ***/

        beacon  = new Beacon(Ethereum.PAUSE_PROXY);
        factory = new PAUFactory(address(beacon));

        rateLimits     = IRateLimits(factory.deployRateLimits(Ethereum.SPARK_PROXY));
        accessControls = IAccessControls(factory.deployAccessControls(Ethereum.SPARK_PROXY));
        almProxy       = IALMProxy(factory.deployALMProxy(Ethereum.SPARK_PROXY));

        mainnetController = IMainnetControllerFull(
            payable(factory.deployController(address(accessControls), address(almProxy), address(rateLimits)))
        );

        vm.startPrank(Ethereum.SPARK_PROXY);

        almProxy.grantRole(almProxy.CONTROLLER(),     address(mainnetController));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(mainnetController));

        vm.stopPrank();

        vm.startPrank(Ethereum.PAUSE_PROXY);

        // Facet wiring
        _onboardAave();
        _onboardAaveV4();
        _onboardBasin();
        _onboardCCTP();
        _onboardCentrifuge();
        _onboardCurve();
        _onboardDAIUSDS();
        _onboardDualPool();
        _onboardERC4626();
        _onboardERC7540();
        _onboardEthena();
        _onboardFarm();
        _onboardLayerZero();
        _onboardMaple();
        _onboardMerkl();
        _onboardNFATHalo();
        _onboardNFATPrime();
        _onboardOTC();
        _onboardPendle();
        _onboardPSM();
        _onboardSparkVault();
        _onboardSuperstate();
        _onboardTransferAsset();
        _onboardUniswapV3();
        _onboardUniswapV4();
        _onboardUSDS();
        _onboardWEETH();
        _onboardWrapProxyETH();
        _onboardWSTETH();

        vm.stopPrank();

        // Step 4: Initialize through Sky governance (Sky spell payload)

        _pauseProxyInitAlmSystem(Ethereum.PSM, address(almProxy));

        // Step 5: Initialize through Spark governance (Spark spell payload)

        vm.startPrank(Ethereum.SPARK_PROXY);

        accessControls.grantRole(ALLOCATOR_ROLE,       allocator);
        accessControls.grantRole(ALLOCATOR_ROLE,       backstopAllocator);
        accessControls.grantRole(ALLOCATOR_ADMIN_ROLE, allocatorAdmin);

        // NOTE: In practice the ALLOCATOR_ADMIN_ROLE will be a wrapper module with custom role
        //       logic that calls into AccessControls to perform grants and revocations.
        accessControls.setRoleAdmin(ALLOCATOR_ROLE, ALLOCATOR_ADMIN_ROLE);

        bytes32[] memory integrationIds = new bytes32[](29);
        integrationIds[0]  = "AAVE_FACET";
        integrationIds[1]  = "BASIN_FACET";
        integrationIds[2]  = "CCTP_FACET";
        integrationIds[3]  = "CENTRIFUGE_FACET";
        integrationIds[4]  = "CURVE_FACET";
        integrationIds[5]  = "DAIUSDS_FACET";
        integrationIds[6]  = "ERC4626_FACET";
        integrationIds[7]  = "ERC7540_FACET";
        integrationIds[8]  = "FARM_FACET";
        integrationIds[9]  = "LAYER_ZERO_FACET";
        integrationIds[10] = "MAPLE_FACET";
        integrationIds[11] = "MERKL_FACET";
        integrationIds[12] = "OTC_FACET";
        integrationIds[13] = "PENDLE_FACET";
        integrationIds[14] = "PSM_FACET";
        integrationIds[15] = "SPARK_VAULT_FACET";
        integrationIds[16] = "SUPERSTATE_FACET";
        integrationIds[17] = "TRANSFER_ASSET_FACET";
        integrationIds[18] = "UNISWAP_V3_FACET";
        integrationIds[19] = "UNISWAP_V4_FACET";
        integrationIds[20] = "ETHENA_FACET";
        integrationIds[21] = "USDS_FACET";
        integrationIds[22] = "WEETH_FACET";
        integrationIds[23] = "WRAP_PROXY_ETH_FACET";
        integrationIds[24] = "WSTETH_FACET";
        integrationIds[25] = "NFAT_HALO_FACET";
        integrationIds[26] = "NFAT_PRIME_FACET";
        integrationIds[27] = "AAVE_V4_FACET";
        integrationIds[28] = "DUAL_POOL_FACET";

        mainnetController.updateIntegrations(integrationIds);

        IVaultLike(ilkInst.vault).rely(address(almProxy));
        IBufferLike(IVaultLike(ilkInst.vault).buffer()).approve(address(usds), address(almProxy), type(uint256).max);

        // NOTE: Using minimal config for test base setup
        rateLimits.setRateLimitData(
            mainnetController.usds_mintRateLimitKey(),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.psm_usdcToUSDSSwapRateLimitKey(),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        rateLimits.setRateLimitData(
            mainnetController.psm_usdsToUSDCSwapRateLimitKey(),
            5_000_000e6,
            uint256(1_000_000e6) / 4 hours
        );

        vm.stopPrank();

        /*** Step 6: Label addresses ***/

        vm.label(buffer,         "buffer");
        vm.label(Ethereum.SUSDS, "susds");
        vm.label(address(usdc),  "usdc");
        vm.label(address(usds),  "usds");
        vm.label(vault,          "vault");
    }

    // Default configuration for the fork, can be overridden in inheriting tests
    function _getBlock() internal pure virtual returns (uint256) {
        return 20917850; //  October 7, 2024
    }

    function _absSubtraction(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _setControllerEntered() internal virtual {
        vm.store(address(mainnetController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        _assertReentrancyGuardWrittenToTwice(address(mainnetController));
    }

    function _assertReentrancyGuardWrittenToTwice(address controller) internal {
        ( , bytes32[] memory writeSlots ) = vm.accesses(controller);

        uint256 count = 0;

        for (uint256 i = 0; i < writeSlots.length; ++i) {
            if (writeSlots[i] != _REENTRANCY_GUARD_SLOT) continue;

            ++count;
        }

        assertEq(count, 2);
        assertEq(vm.load(controller, _REENTRANCY_GUARD_SLOT), _REENTRANCY_GUARD_NOT_ENTERED);
    }

    function _pauseProxyInitAlmSystem(address psm, address almProxy) internal {
        vm.prank(Ethereum.PAUSE_PROXY);
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

    /**********************************************************************************************/
    /*** Facet onboarding helpers                                                               ***/
    /**********************************************************************************************/

    function _onboardAave() internal {
        address aaveFacet = address(new AaveFacet());
        vm.label(aaveFacet, "AaveFacet");
        BeaconConfig.setAaveIntegration(address(beacon), aaveFacet);
    }

    function _onboardAaveV4() internal {
        address aaveV4Facet = address(new AaveV4Facet());
        vm.label(aaveV4Facet, "AaveV4Facet");
        BeaconConfig.setAaveV4Integration(address(beacon), aaveV4Facet);
    }

    function _onboardBasin() internal {
        address basinFacet = address(new BasinFacet());
        vm.label(basinFacet, "BasinFacet");
        BeaconConfig.setBasinIntegration(address(beacon), basinFacet);
    }

    function _onboardCCTP() internal {
        address cctpFacet = address(new CCTPFacet(CCTP_MESSENGER, address(usdc)));
        vm.label(cctpFacet, "CCTPFacet");
        BeaconConfig.setCCTPIntegration(address(beacon), cctpFacet);
    }

    function _onboardCentrifuge() internal {
        address centrifugeFacet = address(new CentrifugeFacet());
        vm.label(centrifugeFacet, "CentrifugeFacet");
        BeaconConfig.setCentrifugeIntegration(address(beacon), centrifugeFacet);
    }

    function _onboardCurve() internal {
        address curveFacet = address(new CurveFacet());
        vm.label(curveFacet, "CurveFacet");
        BeaconConfig.setCurveIntegration(address(beacon), curveFacet);
    }

    function _onboardDAIUSDS() internal {
        address daiUSDSFacet = address(new DAIUSDSFacet({
            dai_: Ethereum.DAI,
            daiUSDS_: Ethereum.DAI_USDS,
            usds_: Ethereum.USDS
        }));

        vm.label(daiUSDSFacet, "DAIUSDSFacet");
        BeaconConfig.setDAIUSDSIntegration(address(beacon), daiUSDSFacet);
    }

    function _onboardDualPool() internal {
        address dualPoolFacet = address(new DualPoolFacet());
        vm.label(dualPoolFacet, "DualPoolFacet");
        BeaconConfig.setDualPoolIntegration(address(beacon), dualPoolFacet);
    }

    function _onboardERC4626() internal {
        address erc4626Facet = address(new ERC4626Facet());
        vm.label(erc4626Facet, "ERC4626Facet");
        BeaconConfig.setERC4626Integration(address(beacon), erc4626Facet);
    }

    function _onboardERC7540() internal {
        address erc7540Facet = address(new ERC7540Facet());
        vm.label(erc7540Facet, "ERC7540Facet");
        BeaconConfig.setERC7540Integration(address(beacon), erc7540Facet);
    }

    function _onboardEthena() internal {
        address ethenaFacet =
            address(new EthenaFacet(ETHENA_MINTER, address(susde), address(usdc), address(usde)));

        vm.label(ethenaFacet, "EthenaFacet");
        BeaconConfig.setEthenaIntegration(address(beacon), ethenaFacet);
    }

    function _onboardFarm() internal {
        address farmFacet = address(new FarmFacet());
        vm.label(farmFacet, "FarmFacet");
        BeaconConfig.setFarmIntegration(address(beacon), farmFacet);
    }

    function _onboardLayerZero() internal {
        address layerZeroFacet = address(new LayerZeroFacet());
        vm.label(layerZeroFacet, "LayerZeroFacet");
        BeaconConfig.setLayerZeroIntegration(address(beacon), layerZeroFacet);
    }

    function _onboardMaple() internal {
        address mapleFacet = address(new MapleFacet());
        vm.label(mapleFacet, "MapleFacet");
        BeaconConfig.setMapleIntegration(address(beacon), mapleFacet);
    }

    function _onboardMerkl() internal {
        address merklFacet = address(new MerklFacet());
        vm.label(merklFacet, "MerklFacet");
        BeaconConfig.setMerklIntegration(address(beacon), merklFacet);
    }

    function _onboardNFATHalo() internal {
        address nfatHaloFacet = address(new NFATHaloFacet());
        vm.label(nfatHaloFacet, "NFATHaloFacet");
        BeaconConfig.setNFATHaloIntegration(address(beacon), nfatHaloFacet);
    }

    function _onboardNFATPrime() internal {
        address nfatPrimeFacet = address(new NFATPrimeFacet());
        vm.label(nfatPrimeFacet, "NFATPrimeFacet");
        BeaconConfig.setNFATPrimeIntegration(address(beacon), nfatPrimeFacet);
    }

    function _onboardOTC() internal {
        address otcFacet = address(new OTCFacet());
        vm.label(otcFacet, "OTCFacet");
        BeaconConfig.setOTCIntegration(address(beacon), otcFacet);
    }

    function _onboardPendle() internal {
        address pendleFacet = address(new PendleFacet(GroveEthereum.PENDLE_ROUTER));
        vm.label(pendleFacet, "PendleFacet");
        BeaconConfig.setPendleIntegration(address(beacon), pendleFacet);
    }

    function _onboardPSM() internal {
        address psmFacet =
            address(
                new PSMFacet(
                    Ethereum.DAI,
                    Ethereum.DAI_USDS,
                    Ethereum.PSM,
                    Ethereum.USDC,
                    Ethereum.USDS
                )
            );

        vm.label(psmFacet, "PSMFacet");
        BeaconConfig.setPSMIntegration(address(beacon), psmFacet);
    }

    function _onboardSparkVault() internal {
        address sparkVaultFacet = address(new SparkVaultFacet());
        vm.label(sparkVaultFacet, "SparkVaultFacet");
        BeaconConfig.setSparkVaultIntegration(address(beacon), sparkVaultFacet);
    }

    function _onboardSuperstate() internal {
        address superstateFacet = address(new SuperstateFacet(Ethereum.USDC, Ethereum.USTB));
        vm.label(superstateFacet, "SuperstateFacet");
        BeaconConfig.setSuperstateIntegration(address(beacon), superstateFacet);
    }

    function _onboardTransferAsset() internal {
        address transferAssetFacet = address(new TransferAssetFacet());
        vm.label(transferAssetFacet, "TransferAssetFacet");
        BeaconConfig.setTransferAssetIntegration(address(beacon), transferAssetFacet);
    }

    function _onboardUniswapV3() internal {
        address uniswapV3Facet =
            address(new UniswapV3Facet(UNISWAP_V3_POSITION_MANAGER, UNISWAP_V3_ROUTER));

        vm.label(uniswapV3Facet, "UniswapV3Facet");
        BeaconConfig.setUniswapV3Integration(address(beacon), uniswapV3Facet);
    }

    function _onboardUniswapV4() internal {
        address uniswapV4Facet =
            address(new UniswapV4Facet(_PERMIT2, _UNISWAP_V4_POSITION_MANAGER, _UNISWAP_V4_ROUTER));

        vm.label(uniswapV4Facet, "UniswapV4Facet");
        BeaconConfig.setUniswapV4Integration(address(beacon), uniswapV4Facet);
    }

    function _onboardUSDS() internal {
        address usdsFacet = address(new USDSFacet(address(usds)));
        vm.label(usdsFacet, "USDSFacet");
        BeaconConfig.setUSDSIntegration(address(beacon), usdsFacet);
    }

    function _onboardWEETH() internal {
        address weethFacet = address(new WEETHFacet(Ethereum.WEETH, Ethereum.WETH));
        vm.label(weethFacet, "WEETHFacet");
        BeaconConfig.setWEETHIntegration(address(beacon), weethFacet);
    }

    function _onboardWrapProxyETH() internal {
        address wrapProxyETHFacet = address(new WrapProxyETHFacet(Ethereum.WETH));
        vm.label(wrapProxyETHFacet, "WrapProxyETHFacet");
        BeaconConfig.setWrapProxyETHIntegration(address(beacon), wrapProxyETHFacet);
    }

    function _onboardWSTETH() internal {
        address wstethFacet =
            address(
                new WSTETHFacet(Ethereum.WETH, Ethereum.WSTETH_WITHDRAW_QUEUE, Ethereum.WSTETH)
            );

        vm.label(wstethFacet, "WSTETHFacet");
        BeaconConfig.setWSTETHIntegration(address(beacon), wstethFacet);
    }

}
