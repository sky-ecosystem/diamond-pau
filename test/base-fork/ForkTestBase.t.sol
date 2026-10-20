// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IERC20 } from "../../lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base } from "../../lib/spark-address-registry/src/Base.sol";

import { Base as GroveBase } from "../../lib/grove-address-registry/src/Base.sol";

import { PSM3Deploy } from "../../lib/spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }      from "../../lib/spark-psm/src/PSM3.sol";

import { AaveFacet }          from "../../src/facets/aave/AaveFacet.sol";
import { ERC4626Facet }       from "../../src/facets/erc4626/ERC4626Facet.sol";
import { MerklFacet }         from "../../src/facets/merkl/MerklFacet.sol";
import { PendleFacet }        from "../../src/facets/pendle/PendleFacet.sol";
import { PSM3Facet }          from "../../src/facets/psm3/PSM3Facet.sol";
import { SparkVaultFacet }    from "../../src/facets/spark-vault/SparkVaultFacet.sol";
import { TransferAssetFacet } from "../../src/facets/transfer-asset/TransferAssetFacet.sol";
import { UniswapV3Facet }     from "../../src/facets/uniswap-v3/UniswapV3Facet.sol";

import { IAccessControls } from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../../src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";

import { BeaconConfig } from "../../src/libraries/BeaconConfig.sol";

import { Beacon }     from "../../src/Beacon.sol";
import { PAUFactory } from "../../src/PAUFactory.sol";

import { IForeignControllerFull } from "../interfaces/IForeignControllerFull.sol";

abstract contract ForkTestBase is Test {

    // TODO: Refactor to use live addresses

    struct MintRecipient {
        uint32  domain;
        bytes32 mintRecipient;
    }

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    address internal constant UNISWAP_V3_ROUTER           = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address internal constant UNISWAP_V3_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _REENTRANCY_GUARD_SLOT        = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;
    bytes32 internal constant _REENTRANCY_GUARD_NOT_ENTERED = bytes32(uint256(1));
    bytes32 internal constant _REENTRANCY_GUARD_ENTERED     = bytes32(uint256(2));

    bytes32 constant ALLOCATOR_ROLE       = keccak256("ALLOCATOR_ROLE");
    bytes32 constant ALLOCATOR_ADMIN_ROLE = keccak256("ALLOCATOR_ADMIN_ROLE");
    bytes32 constant DEFAULT_ADMIN_ROLE   = 0x00;

    address allocator      = Base.ALM_RELAYER_MULTISIG;
    address allocatorAdmin = Base.ALM_FREEZER_MULTISIG;

    address pocket   = makeAddr("pocket");
    address skyAdmin = makeAddr("skyAdmin");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address constant SPARK_EXECUTOR = Base.SPARK_EXECUTOR;
    address constant SSR_ORACLE     = Base.SSR_AUTH_ORACLE;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    Beacon                 beacon;
    IAccessControls        accessControls;
    IALMProxy              almProxy;
    IForeignControllerFull foreignController;
    IRateLimits            rateLimits;
    PAUFactory             factory;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    IPSM3 psmBase;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {
        /*** Step 1: Set up environment, deploy mock addresses ***/

        vm.createSelectFork(getChain('base').rpcUrl, _getBlock());

        usdsBase  = IERC20(address(new ERC20Mock()));
        susdsBase = IERC20(address(new ERC20Mock()));
        usdcBase  = IERC20(Base.USDC);

        /*** Step 2: Deploy and configure PSM with a pocket ***/

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            SPARK_EXECUTOR, Base.USDC, address(usdsBase), address(susdsBase), SSR_ORACLE
        ));

        vm.prank(SPARK_EXECUTOR);
        psmBase.setPocket(pocket);

        vm.prank(pocket);
        usdcBase.approve(address(psmBase), type(uint256).max);

        /*** Step 3: Deploy ALM system ***/

        beacon  = new Beacon(skyAdmin);
        factory = new PAUFactory(address(beacon));

        rateLimits     = IRateLimits(factory.deployRateLimits(SPARK_EXECUTOR));
        accessControls = IAccessControls(factory.deployAccessControls(SPARK_EXECUTOR));
        almProxy       = IALMProxy(factory.deployALMProxy(SPARK_EXECUTOR));

        foreignController = IForeignControllerFull(
            payable(factory.deployController(address(accessControls), address(almProxy), address(rateLimits)))
        );

        vm.startPrank(SPARK_EXECUTOR);

        almProxy.grantRole(almProxy.CONTROLLER(),     address(foreignController));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(foreignController));

        vm.stopPrank();

        vm.startPrank(skyAdmin);

        _onboardAave();
        _onboardERC4626();
        _onboardMerkl();
        _onboardPendle();
        _onboardPSM3();
        _onboardSparkVault();
        _onboardTransferAsset();
        _onboardUniswapV3();

        vm.stopPrank();

        vm.startPrank(SPARK_EXECUTOR);

        accessControls.grantRole(ALLOCATOR_ROLE,       allocator);
        accessControls.grantRole(ALLOCATOR_ADMIN_ROLE, allocatorAdmin);

        // NOTE: In practice the ALLOCATOR_ADMIN_ROLE will be a wrapper module with custom role
        //       logic that calls into AccessControls to perform grants and revocations.
        accessControls.setRoleAdmin(ALLOCATOR_ROLE, ALLOCATOR_ADMIN_ROLE);

        bytes32[] memory integrationIds = new bytes32[](8);
        integrationIds[0] = "AAVE_FACET";
        integrationIds[1] = "ERC4626_FACET";
        integrationIds[2] = "MERKL_FACET";
        integrationIds[3] = "PENDLE_FACET";
        integrationIds[4] = "PSM3_FACET";
        integrationIds[5] = "SPARK_VAULT_FACET";
        integrationIds[6] = "TRANSFER_ASSET_FACET";
        integrationIds[7] = "UNISWAP_V3_FACET";

        foreignController.updateIntegrations(integrationIds);

        /*** Step 4: Configure ALM system parameters through Spark governance ***/

        uint256 usdcMaxAmount = 5_000_000e6;
        uint256 usdcSlope     = uint256(1_000_000e6) / 4 hours;
        uint256 usdsMaxAmount = 5_000_000e18;
        uint256 usdsSlope     = uint256(1_000_000e18) / 4 hours;

        // NOTE: Using minimal config for test base setup
        rateLimits.setRateLimitData(
            foreignController.psm3_getDepositRateLimitKey(address(usdcBase)),
            usdcMaxAmount,
            usdcSlope
        );

        rateLimits.setRateLimitData(
            foreignController.psm3_getWithdrawRateLimitKey(address(usdcBase)),
            usdcMaxAmount,
            usdcSlope
        );

        rateLimits.setRateLimitData(
            foreignController.psm3_getDepositRateLimitKey(address(usdsBase)),
            usdsMaxAmount,
            usdsSlope
        );

        rateLimits.setRateLimitData(
            foreignController.psm3_getDepositRateLimitKey(address(susdsBase)),
            usdsMaxAmount,
            usdsSlope
        );

        rateLimits.setUnlimitedRateLimitData(
            foreignController.psm3_getWithdrawRateLimitKey(address(usdsBase))
        );

        rateLimits.setUnlimitedRateLimitData(
            foreignController.psm3_getWithdrawRateLimitKey(address(susdsBase))
        );

        vm.stopPrank();
    }

    // Default configuration for the fork, can be overridden in inheriting tests
    function _getBlock() internal pure virtual returns (uint256) {
        return 20782500;  // October 8, 2024
    }

    function _setControllerEntered() internal {
        vm.store(address(foreignController), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);
    }

    function _assertReentrancyGuardWrittenToTwice() internal {
        ( , bytes32[] memory writeSlots ) = vm.accesses(address(foreignController));

        uint256 count = 0;

        for (uint256 i = 0; i < writeSlots.length; ++i) {
            if (writeSlots[i] != _REENTRANCY_GUARD_SLOT) continue;

            ++count;
        }

        assertEq(count, 2);
        assertEq(vm.load(address(foreignController), _REENTRANCY_GUARD_SLOT), _REENTRANCY_GUARD_NOT_ENTERED);
    }

    function _absSubtraction(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**********************************************************************************************/
    /*** Facet onboarding helpers                                                               ***/
    /**********************************************************************************************/

    function _onboardAave() internal {
        address aaveFacet = address(new AaveFacet());
        vm.label(aaveFacet, "AaveFacet");
        BeaconConfig.setAaveIntegration(address(beacon), aaveFacet);
    }

    function _onboardERC4626() internal {
        address erc4626Facet = address(new ERC4626Facet());
        vm.label(erc4626Facet, "ERC4626Facet");
        BeaconConfig.setERC4626Integration(address(beacon), erc4626Facet);
    }

    function _onboardMerkl() internal {
        address merklFacet = address(new MerklFacet());
        vm.label(merklFacet, "MerklFacet");
        BeaconConfig.setMerklIntegration(address(beacon), merklFacet);
    }

    function _onboardPendle() internal {
        address pendleFacet = address(new PendleFacet(GroveBase.PENDLE_ROUTER));
        vm.label(pendleFacet, "PendleFacet");
        BeaconConfig.setPendleIntegration(address(beacon), pendleFacet);
    }

    function _onboardPSM3() internal {
        address psm3Facet = address(new PSM3Facet(address(psmBase)));
        vm.label(psm3Facet, "PSM3Facet");
        BeaconConfig.setPSM3Integration(address(beacon), psm3Facet);
    }

    function _onboardSparkVault() internal {
        address sparkVaultFacet = address(new SparkVaultFacet());
        vm.label(sparkVaultFacet, "SparkVaultFacet");
        BeaconConfig.setSparkVaultIntegration(address(beacon), sparkVaultFacet);
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

}
