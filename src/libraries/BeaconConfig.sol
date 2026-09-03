// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IBeacon }                 from "../interfaces/IBeacon.sol";
import { IEnumerableIntegrations } from "../interfaces/IEnumerableIntegrations.sol";

import { IFacet } from "../facets/IFacet.sol";

import { IAaveController }          from "../facets/aave/IAaveController.sol";
import { IAaveFacet }               from "../facets/aave/IAaveFacet.sol";
import { IAaveV4Controller }        from "../facets/aave-v4/IAaveV4Controller.sol";
import { IAaveV4Facet }             from "../facets/aave-v4/IAaveV4Facet.sol";
import { IBasinController }         from "../facets/basin/IBasinController.sol";
import { IBasinFacet }              from "../facets/basin/IBasinFacet.sol";
import { ICCTPController }          from "../facets/cctp/ICCTPController.sol";
import { ICCTPFacet }               from "../facets/cctp/ICCTPFacet.sol";
import { ICentrifugeController }    from "../facets/centrifuge/ICentrifugeController.sol";
import { ICentrifugeFacet }         from "../facets/centrifuge/ICentrifugeFacet.sol";
import { ICurveController }         from "../facets/curve/ICurveController.sol";
import { ICurveFacet }              from "../facets/curve/ICurveFacet.sol";
import { IDAIUSDSController }       from "../facets/dai-usds/IDAIUSDSController.sol";
import { IDAIUSDSFacet }            from "../facets/dai-usds/IDAIUSDSFacet.sol";
import { IDualPoolController }      from "../facets/dual-pool/IDualPoolController.sol";
import { IDualPoolFacet }           from "../facets/dual-pool/IDualPoolFacet.sol";
import { IERC4626Controller }       from "../facets/erc4626/IERC4626Controller.sol";
import { IERC4626Facet }            from "../facets/erc4626/IERC4626Facet.sol";
import { IERC7540Controller }       from "../facets/erc7540/IERC7540Controller.sol";
import { IERC7540Facet }            from "../facets/erc7540/IERC7540Facet.sol";
import { IEthenaController }        from "../facets/ethena/IEthenaController.sol";
import { IEthenaFacet }             from "../facets/ethena/IEthenaFacet.sol";
import { IFarmController }          from "../facets/farm/IFarmController.sol";
import { IFarmFacet }               from "../facets/farm/IFarmFacet.sol";
import { ILayerZeroController }     from "../facets/layer-zero/ILayerZeroController.sol";
import { ILayerZeroFacet }          from "../facets/layer-zero/ILayerZeroFacet.sol";
import { IMapleController }         from "../facets/maple/IMapleController.sol";
import { IMapleFacet }              from "../facets/maple/IMapleFacet.sol";
import { IMerklController }         from "../facets/merkl/IMerklController.sol";
import { IMerklFacet }              from "../facets/merkl/IMerklFacet.sol";
import { INFATHaloController }      from "../facets/nfat-halo/INFATHaloController.sol";
import { INFATHaloFacet }           from "../facets/nfat-halo/INFATHaloFacet.sol";
import { INFATPrimeController }     from "../facets/nfat-prime/INFATPrimeController.sol";
import { INFATPrimeFacet }          from "../facets/nfat-prime/INFATPrimeFacet.sol";
import { IOTCController }           from "../facets/otc/IOTCController.sol";
import { IOTCFacet }                from "../facets/otc/IOTCFacet.sol";
import { IPendleController }        from "../facets/pendle/IPendleController.sol";
import { IPendleFacet }             from "../facets/pendle/IPendleFacet.sol";
import { IPSM3Controller }          from "../facets/psm3/IPSM3Controller.sol";
import { IPSM3Facet }               from "../facets/psm3/IPSM3Facet.sol";
import { IPSMController }           from "../facets/psm/IPSMController.sol";
import { IPSMFacet }                from "../facets/psm/IPSMFacet.sol";
import { ISparkVaultController }    from "../facets/spark-vault/ISparkVaultController.sol";
import { ISparkVaultFacet }         from "../facets/spark-vault/ISparkVaultFacet.sol";
import { ISuperstateController }    from "../facets/superstate/ISuperstateController.sol";
import { ISuperstateFacet }         from "../facets/superstate/ISuperstateFacet.sol";
import { ITransferAssetController } from "../facets/transfer-asset/ITransferAssetController.sol";
import { ITransferAssetFacet }      from "../facets/transfer-asset/ITransferAssetFacet.sol";
import { IUniswapV3Controller }     from "../facets/uniswap-v3/IUniswapV3Controller.sol";
import { IUniswapV3Facet }          from "../facets/uniswap-v3/IUniswapV3Facet.sol";
import { IUniswapV4Controller }     from "../facets/uniswap-v4/IUniswapV4Controller.sol";
import { IUniswapV4Facet }          from "../facets/uniswap-v4/IUniswapV4Facet.sol";
import { IUSDSController }          from "../facets/usds/IUSDSController.sol";
import { IUSDSFacet }               from "../facets/usds/IUSDSFacet.sol";
import { IWEETHController }         from "../facets/weeth/IWEETHController.sol";
import { IWEETHFacet }              from "../facets/weeth/IWEETHFacet.sol";
import { IWrapProxyETHController }  from "../facets/wrap-proxy-eth/IWrapProxyETHController.sol";
import { IWrapProxyETHFacet }       from "../facets/wrap-proxy-eth/IWrapProxyETHFacet.sol";
import { IWSTETHController }        from "../facets/wsteth/IWSTETHController.sol";
import { IWSTETHFacet }             from "../facets/wsteth/IWSTETHFacet.sol";

/**
 * @title  BeaconConfig
 * @notice Library used to configure facet integrations at the beacons.
 */
library BeaconConfig {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @notice Integration identifier for the Aave facet.
    bytes32 internal constant AAVE_INTEGRATION = "AAVE_FACET";

    /// @notice Integration identifier for the Aave V4 facet.
    bytes32 internal constant AAVE_V4_INTEGRATION = "AAVE_V4_FACET";

    /// @notice Integration identifier for the Basin facet.
    bytes32 internal constant BASIN_INTEGRATION = "BASIN_FACET";

    /// @notice Integration identifier for the CCTP facet.
    bytes32 internal constant CCTP_INTEGRATION = "CCTP_FACET";

    /// @notice Integration identifier for the Centrifuge facet.
    bytes32 internal constant CENTRIFUGE_INTEGRATION = "CENTRIFUGE_FACET";

    /// @notice Integration identifier for the Curve facet.
    bytes32 internal constant CURVE_INTEGRATION = "CURVE_FACET";

    /// @notice Integration identifier for the DAI-USDS facet.
    bytes32 internal constant DAIUSDS_INTEGRATION = "DAIUSDS_FACET";

    /// @notice Integration identifier for the Dual Pool facet.
    bytes32 internal constant DUAL_POOL_INTEGRATION = "DUAL_POOL_FACET";

    /// @notice Integration identifier for the ERC-4626 facet.
    bytes32 internal constant ERC4626_INTEGRATION = "ERC4626_FACET";

    /// @notice Integration identifier for the ERC-7540 facet.
    bytes32 internal constant ERC7540_INTEGRATION = "ERC7540_FACET";

    /// @notice Integration identifier for the Ethena facet.
    bytes32 internal constant ETHENA_INTEGRATION = "ETHENA_FACET";

    /// @notice Integration identifier for the Farm facet.
    bytes32 internal constant FARM_INTEGRATION = "FARM_FACET";

    /// @notice Integration identifier for the LayerZero facet.
    bytes32 internal constant LAYER_ZERO_INTEGRATION = "LAYER_ZERO_FACET";

    /// @notice Integration identifier for the Maple facet.
    bytes32 internal constant MAPLE_INTEGRATION = "MAPLE_FACET";

    /// @notice Integration identifier for the Merkl facet.
    bytes32 internal constant MERKL_INTEGRATION = "MERKL_FACET";

    /// @notice Integration identifier for the NFAT Halo facet.
    bytes32 internal constant NFAT_HALO_INTEGRATION = "NFAT_HALO_FACET";

    /// @notice Integration identifier for the NFAT Prime facet.
    bytes32 internal constant NFAT_PRIME_INTEGRATION = "NFAT_PRIME_FACET";

    /// @notice Integration identifier for the OTC facet.
    bytes32 internal constant OTC_INTEGRATION = "OTC_FACET";

    /// @notice Integration identifier for the Pendle facet.
    bytes32 internal constant PENDLE_INTEGRATION = "PENDLE_FACET";

    /// @notice Integration identifier for the PSM facet.
    bytes32 internal constant PSM_INTEGRATION = "PSM_FACET";

    /// @notice Integration identifier for the PSM3 facet.
    bytes32 internal constant PSM3_INTEGRATION = "PSM3_FACET";

    /// @notice Integration identifier for the Spark Vault facet.
    bytes32 internal constant SPARK_VAULT_INTEGRATION = "SPARK_VAULT_FACET";

    /// @notice Integration identifier for the Superstate facet.
    bytes32 internal constant SUPERSTATE_INTEGRATION = "SUPERSTATE_FACET";

    /// @notice Integration identifier for the Transfer Asset facet.
    bytes32 internal constant TRANSFER_ASSET_INTEGRATION = "TRANSFER_ASSET_FACET";

    /// @notice Integration identifier for the Uniswap V3 facet.
    bytes32 internal constant UNISWAP_V3_INTEGRATION = "UNISWAP_V3_FACET";

    /// @notice Integration identifier for the Uniswap V4 facet.
    bytes32 internal constant UNISWAP_V4_INTEGRATION = "UNISWAP_V4_FACET";

    /// @notice Integration identifier for the USDS facet.
    bytes32 internal constant USDS_INTEGRATION = "USDS_FACET";

    /// @notice Integration identifier for the WEETH facet.
    bytes32 internal constant WEETH_INTEGRATION = "WEETH_FACET";

    /// @notice Integration identifier for the Wrap Proxy ETH facet.
    bytes32 internal constant WRAP_PROXY_ETH_INTEGRATION = "WRAP_PROXY_ETH_FACET";

    /// @notice Integration identifier for the WSTETH facet.
    bytes32 internal constant WSTETH_INTEGRATION = "WSTETH_FACET";

    /**********************************************************************************************/
    /*** Aave Integration                                                                       ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Aave facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed AaveFacet contract.
     */
    function setAaveIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](7);

        wires[0] = IEnumerableIntegrations.Wire(
            IAaveController.aave_setMaxSlippage.selector,
            IAaveFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IAaveController.aave_getMaxSlippage.selector,
            IAaveFacet.getMaxSlippage.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IAaveController.aave_deposit.selector,
            IAaveFacet.deposit.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IAaveController.aave_withdraw.selector,
            IAaveFacet.withdraw.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IAaveController.aave_getDepositRateLimitKey.selector,
            IAaveFacet.getDepositRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IAaveController.aave_getWithdrawRateLimitKey.selector,
            IAaveFacet.getWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IAaveController.aave_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(AAVE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** AaveV4 Integration                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the AaveV4 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed AaveV4Facet contract.
     */
    function setAaveV4Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](9);

        wires[0] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_setMaxDeficit.selector,
            IAaveV4Facet.setMaxDeficit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_getMaxDeficit.selector,
            IAaveV4Facet.getMaxDeficit.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_setMaxSlippage.selector,
            IAaveV4Facet.setMaxSlippage.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_getMaxSlippage.selector,
            IAaveV4Facet.getMaxSlippage.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_deposit.selector,
            IAaveV4Facet.deposit.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_withdraw.selector,
            IAaveV4Facet.withdraw.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_getDepositRateLimitKey.selector,
            IAaveV4Facet.getDepositRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_getWithdrawRateLimitKey.selector,
            IAaveV4Facet.getWithdrawRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IAaveV4Controller.aaveV4_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(AAVE_V4_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Basin Integration                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Basin facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed BasinFacet contract.
     */
    function setBasinIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](5);

        wires[0] = IEnumerableIntegrations.Wire(
            IBasinController.basin_deposit.selector,
            IBasinFacet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IBasinController.basin_withdraw.selector,
            IBasinFacet.withdraw.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IBasinController.basin_getDepositRateLimitKey.selector,
            IBasinFacet.getDepositRateLimitKey.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IBasinController.basin_getWithdrawRateLimitKey.selector,
            IBasinFacet.getWithdrawRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IBasinController.basin_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(BASIN_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** CCTP Integration                                                                       ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the CCTP facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed CCTPFacet contract.
     */
    function setCCTPIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](10);

        wires[0] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_setDomainParameters.selector,
            ICCTPFacet.setDomainParameters.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_transfer.selector,
            ICCTPFacet.transfer.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_toCCTPRateLimitKey.selector,
            ICCTPFacet.toCCTPRateLimitKey.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_getDomainParameters.selector,
            ICCTPFacet.getDomainParameters.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_getToDomainRateLimitKey.selector,
            ICCTPFacet.getToDomainRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_DESTINATION_CALLER.selector,
            ICCTPFacet.DESTINATION_CALLER.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_MIN_FINALITY_THRESHOLD.selector,
            ICCTPFacet.MIN_FINALITY_THRESHOLD.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_cctp.selector,
            ICCTPFacet.cctp.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            ICCTPController.cctp_usdc.selector,
            ICCTPFacet.usdc.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(CCTP_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Centrifuge Integration                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Centrifuge facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed CentrifugeFacet contract.
     */
    function setCentrifugeIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](14);

        wires[0] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_setRecipient.selector,
            ICentrifugeFacet.setRecipient.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_cancelDepositRequest.selector,
            ICentrifugeFacet.cancelDepositRequest.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_claimCancelDepositRequest.selector,
            ICentrifugeFacet.claimCancelDepositRequest.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_cancelRedeemRequest.selector,
            ICentrifugeFacet.cancelRedeemRequest.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_claimCancelRedeemRequest.selector,
            ICentrifugeFacet.claimCancelRedeemRequest.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_transferShares.selector,
            ICentrifugeFacet.transferShares.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getRecipient.selector,
            ICentrifugeFacet.getRecipient.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getCancelDepositRateLimitKey.selector,
            ICentrifugeFacet.getCancelDepositRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getClaimCancelDepositRateLimitKey.selector,
            ICentrifugeFacet.getClaimCancelDepositRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getCancelRedeemRateLimitKey.selector,
            ICentrifugeFacet.getCancelRedeemRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getClaimCancelRedeemRateLimitKey.selector,
            ICentrifugeFacet.getClaimCancelRedeemRateLimitKey.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_getTransferRateLimitKey.selector,
            ICentrifugeFacet.getTransferRateLimitKey.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            ICentrifugeController.centrifuge_REQUEST_ID.selector,
            ICentrifugeFacet.REQUEST_ID.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(CENTRIFUGE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Curve Integration                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Curve facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed CurveFacet contract.
     */
    function setCurveIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](11);

        wires[0] = IEnumerableIntegrations.Wire(
            ICurveController.curve_setMaxSlippage.selector,
            ICurveFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getMaxSlippage.selector,
            ICurveFacet.getMaxSlippage.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ICurveController.curve_swap.selector,
            ICurveFacet.swap.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            ICurveController.curve_addLiquidity.selector,
            ICurveFacet.addLiquidity.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            ICurveController.curve_removeLiquidity.selector,
            ICurveFacet.removeLiquidity.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getAggregateDepositRateLimitKey.selector,
            ICurveFacet.getAggregateDepositRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getAssetDepositRateLimitKey.selector,
            ICurveFacet.getAssetDepositRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getSwapRateLimitKey.selector,
            ICurveFacet.getSwapRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getAggregateWithdrawRateLimitKey.selector,
            ICurveFacet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            ICurveController.curve_getAssetWithdrawRateLimitKey.selector,
            ICurveFacet.getAssetWithdrawRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            ICurveController.curve_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(CURVE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** DAIUSDS Integration                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the DAIUSDS facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed DAIUSDSFacet contract.
     */
    function setDAIUSDSIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](8);

        wires[0] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_swapUSDSToDAI.selector,
            IDAIUSDSFacet.swapUSDSToDAI.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_swapDAIToUSDS.selector,
            IDAIUSDSFacet.swapDAIToUSDS.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_daiToUSDSSwapRateLimitKey.selector,
            IDAIUSDSFacet.daiToUSDSSwapRateLimitKey.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_usdsToDAISwapRateLimitKey.selector,
            IDAIUSDSFacet.usdsToDAISwapRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_dai.selector,
            IDAIUSDSFacet.dai.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_daiUSDS.selector,
            IDAIUSDSFacet.daiUSDS.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IDAIUSDSController.daiUSDS_usds.selector,
            IDAIUSDSFacet.usds.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(DAIUSDS_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** DualPool Integration                                                                   ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the DualPool facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed DualPoolFacet contract.
     */
    function setDualPoolIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](9);

        wires[0] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_deposit.selector,
            IDualPoolFacet.deposit.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_setMaxSlippage.selector,
            IDualPoolFacet.setMaxSlippage.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_withdraw.selector,
            IDualPoolFacet.withdraw.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_getAggregateDepositRateLimitKey.selector,
            IDualPoolFacet.getAggregateDepositRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_getAggregateWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_getAssetDepositRateLimitKey.selector,
            IDualPoolFacet.getAssetDepositRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_getAssetWithdrawRateLimitKey.selector,
            IDualPoolFacet.getAssetWithdrawRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IDualPoolController.dualPool_getMaxSlippage.selector,
            IDualPoolFacet.getMaxSlippage.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(DUAL_POOL_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** ERC4626 Integration                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the ERC4626 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed ERC4626Facet contract.
     */
    function setERC4626Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](9);

        wires[0] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_setMaxExchangeRate.selector,
            IERC4626Facet.setMaxExchangeRate.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_deposit.selector,
            IERC4626Facet.deposit.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_withdraw.selector,
            IERC4626Facet.withdraw.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_redeem.selector,
            IERC4626Facet.redeem.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_EXCHANGE_RATE_PRECISION.selector,
            IERC4626Facet.EXCHANGE_RATE_PRECISION.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_getMaxExchangeRate.selector,
            IERC4626Facet.getMaxExchangeRate.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_getDepositRateLimitKey.selector,
            IERC4626Facet.getDepositRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_getWithdrawRateLimitKey.selector,
            IERC4626Facet.getWithdrawRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IERC4626Controller.erc4626_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(ERC4626_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** ERC7540 Integration                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the ERC7540 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed ERC7540Facet contract.
     */
    function setERC7540Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](9);

        wires[0] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_requestDeposit.selector,
            IERC7540Facet.requestDeposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_claimDeposit.selector,
            IERC7540Facet.claimDeposit.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_requestRedeem.selector,
            IERC7540Facet.requestRedeem.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_claimRedeem.selector,
            IERC7540Facet.claimRedeem.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_getRequestDepositRateLimitKey.selector,
            IERC7540Facet.getRequestDepositRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_getClaimDepositRateLimitKey.selector,
            IERC7540Facet.getClaimDepositRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_getRequestRedeemRateLimitKey.selector,
            IERC7540Facet.getRequestRedeemRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_getClaimRedeemRateLimitKey.selector,
            IERC7540Facet.getClaimRedeemRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IERC7540Controller.erc7540_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(ERC7540_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Ethena Integration                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Ethena facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed EthenaFacet contract.
     */
    function setEthenaIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](18);

        wires[0] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_setDelegatedSigner.selector,
            IEthenaFacet.setDelegatedSigner.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_removeDelegatedSigner.selector,
            IEthenaFacet.removeDelegatedSigner.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_prepareMint.selector,
            IEthenaFacet.prepareMint.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_prepareBurn.selector,
            IEthenaFacet.prepareBurn.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_cooldownAssets.selector,
            IEthenaFacet.cooldownAssets.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_cooldownShares.selector,
            IEthenaFacet.cooldownShares.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_unstake.selector,
            IEthenaFacet.unstake.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_setDelegatedSignerRateLimitKey.selector,
            IEthenaFacet.setDelegatedSignerRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_removeDelegatedSignerRateLimitKey.selector,
            IEthenaFacet.removeDelegatedSignerRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_mintRateLimitKey.selector,
            IEthenaFacet.mintRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_burnRateLimitKey.selector,
            IEthenaFacet.burnRateLimitKey.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_cooldownRateLimitKey.selector,
            IEthenaFacet.cooldownRateLimitKey.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_unstakeRateLimitKey.selector,
            IEthenaFacet.unstakeRateLimitKey.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[14] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_minter.selector,
            IEthenaFacet.minter.selector
        );

        wires[15] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_susde.selector,
            IEthenaFacet.susde.selector
        );

        wires[16] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_usdc.selector,
            IEthenaFacet.usdc.selector
        );

        wires[17] = IEnumerableIntegrations.Wire(
            IEthenaController.ethena_usde.selector,
            IEthenaFacet.usde.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(ETHENA_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Farm Integration                                                                       ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Farm facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed FarmFacet contract.
     */
    function setFarmIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](7);

        wires[0] = IEnumerableIntegrations.Wire(
            IFarmController.farm_deposit.selector,
            IFarmFacet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IFarmController.farm_claimReward.selector,
            IFarmFacet.claimReward.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IFarmController.farm_withdraw.selector,
            IFarmFacet.withdraw.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IFarmController.farm_getClaimRewardRateLimitKey.selector,
            IFarmFacet.getClaimRewardRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IFarmController.farm_getDepositRateLimitKey.selector,
            IFarmFacet.getDepositRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IFarmController.farm_getWithdrawRateLimitKey.selector,
            IFarmFacet.getWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IFarmController.farm_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(FARM_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** LayerZero Integration                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the LayerZero facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed LayerZeroFacet contract.
     */
    function setLayerZeroIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](6);

        wires[0] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_setRecipient.selector,
            ILayerZeroFacet.setRecipient.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_transfer.selector,
            ILayerZeroFacet.transfer.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_getRecipient.selector,
            ILayerZeroFacet.getRecipient.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_getTransferRateLimitKey.selector,
            ILayerZeroFacet.getTransferRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_quoteTransfer.selector,
            ILayerZeroFacet.quoteTransfer.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            ILayerZeroController.layerZero_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(LAYER_ZERO_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Maple Integration                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Maple facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed MapleFacet contract.
     */
    function setMapleIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](5);

        wires[0] = IEnumerableIntegrations.Wire(
            IMapleController.maple_requestRedemption.selector,
            IMapleFacet.requestRedemption.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IMapleController.maple_cancelRedemption.selector,
            IMapleFacet.cancelRedemption.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IMapleController.maple_getCancelRedeemRateLimitKey.selector,
            IMapleFacet.getCancelRedeemRateLimitKey.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IMapleController.maple_getRequestRedeemRateLimitKey.selector,
            IMapleFacet.getRequestRedeemRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IMapleController.maple_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(MAPLE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Merkl Integration                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Merkl facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed MerklFacet contract.
     */
    function setMerklIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](3);

        wires[0] = IEnumerableIntegrations.Wire(
            IMerklController.merkl_toggleOperator.selector,
            IMerklFacet.toggleOperator.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IMerklController.merkl_getToggleOperatorRateLimitKey.selector,
            IMerklFacet.getToggleOperatorRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IMerklController.merkl_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(MERKL_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** NFATHalo Integration                                                                   ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the NFATHalo facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed NFATHaloFacet contract.
     */
    function setNFATHaloIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](12);

        wires[0] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_setMaxAnnualGrowthRate.selector,
            INFATHaloFacet.setMaxAnnualGrowthRate.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_issue.selector,
            INFATHaloFacet.issue.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_repayPrincipal.selector,
            INFATHaloFacet.repayPrincipal.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_repayInterest.selector,
            INFATHaloFacet.repayInterest.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getMaxAnnualGrowthRate.selector,
            INFATHaloFacet.getMaxAnnualGrowthRate.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getFacilityState.selector,
            INFATHaloFacet.getFacilityState.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getPosition.selector,
            INFATHaloFacet.getPosition.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getCurrentMaxOutstandingInterest.selector,
            INFATHaloFacet.getCurrentMaxOutstandingInterest.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getIssueRateLimitKey.selector,
            INFATHaloFacet.getIssueRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getRepayInterestRateLimitKey.selector,
            INFATHaloFacet.getRepayInterestRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_getRepayPrincipalRateLimitKey.selector,
            INFATHaloFacet.getRepayPrincipalRateLimitKey.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            INFATHaloController.nfatHalo_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(NFAT_HALO_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** NFATPrime Integration                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the NFATPrime facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed NFATPrimeFacet contract.
     */
    function setNFATPrimeIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](7);

        wires[0] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_subscribe.selector,
            INFATPrimeFacet.subscribe.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_withdraw.selector,
            INFATPrimeFacet.withdraw.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_collect.selector,
            INFATPrimeFacet.collect.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_getSubscribeRateLimitKey.selector,
            INFATPrimeFacet.getSubscribeRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_getCollectRateLimitKey.selector,
            INFATPrimeFacet.getCollectRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_getWithdrawRateLimitKey.selector,
            INFATPrimeFacet.getWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            INFATPrimeController.nfatPrime_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(NFAT_PRIME_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** OTC Integration                                                                        ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the OTC facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed OTCFacet contract.
     */
    function setOTCIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](14);

        wires[0] = IEnumerableIntegrations.Wire(
            IOTCController.otc_setMaxSlippage.selector,
            IOTCFacet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IOTCController.otc_setBuffer.selector,
            IOTCFacet.setBuffer.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IOTCController.otc_setRechargeRate.selector,
            IOTCFacet.setRechargeRate.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IOTCController.otc_send.selector,
            IOTCFacet.send.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IOTCController.otc_claim.selector,
            IOTCFacet.claim.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getBuffer.selector,
            IOTCFacet.getBuffer.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getMaxSlippage.selector,
            IOTCFacet.getMaxSlippage.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getRechargeRate.selector,
            IOTCFacet.getRechargeRate.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getState.selector,
            IOTCFacet.getState.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getClaimWithRecharge.selector,
            IOTCFacet.getClaimWithRecharge.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getIsSwapReady.selector,
            IOTCFacet.getIsSwapReady.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getSendRateLimitKey.selector,
            IOTCFacet.getSendRateLimitKey.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            IOTCController.otc_getClaimRateLimitKey.selector,
            IOTCFacet.getClaimRateLimitKey.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            IOTCController.otc_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(OTC_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Pendle Integration                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Pendle facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed PendleFacet contract.
     */
    function setPendleIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](4);

        wires[0] = IEnumerableIntegrations.Wire(
            IPendleController.pendle_redeem.selector,
            IPendleFacet.redeem.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IPendleController.pendle_getRedeemRateLimitKey.selector,
            IPendleFacet.getRedeemRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IPendleController.pendle_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IPendleController.pendle_router.selector,
            IPendleFacet.router.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(PENDLE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** PSM Integration                                                                        ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the PSM facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed PSMFacet contract.
     */
    function setPSMIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](11);

        wires[0] = IEnumerableIntegrations.Wire(
            IPSMController.psm_swapUSDSToUSDC.selector,
            IPSMFacet.swapUSDSToUSDC.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IPSMController.psm_swapUSDCToUSDS.selector,
            IPSMFacet.swapUSDCToUSDS.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IPSMController.psm_to18ConversionFactor.selector,
            IPSMFacet.to18ConversionFactor.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IPSMController.psm_usdcToUSDSSwapRateLimitKey.selector,
            IPSMFacet.usdcToUSDSSwapRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IPSMController.psm_usdsToUSDCSwapRateLimitKey.selector,
            IPSMFacet.usdsToUSDCSwapRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IPSMController.psm_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IPSMController.psm_dai.selector,
            IPSMFacet.dai.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IPSMController.psm_daiUSDS.selector,
            IPSMFacet.daiUSDS.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IPSMController.psm_psm.selector,
            IPSMFacet.psm.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IPSMController.psm_usdc.selector,
            IPSMFacet.usdc.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IPSMController.psm_usds.selector,
            IPSMFacet.usds.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(PSM_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** PSM3 Integration                                                                       ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the PSM3 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed PSM3Facet contract.
     */
    function setPSM3Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](6);

        wires[0] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_deposit.selector,
            IPSM3Facet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_withdraw.selector,
            IPSM3Facet.withdraw.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_getDepositRateLimitKey.selector,
            IPSM3Facet.getDepositRateLimitKey.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_getWithdrawRateLimitKey.selector,
            IPSM3Facet.getWithdrawRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IPSM3Controller.psm3_psm.selector,
            IPSM3Facet.psm.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(PSM3_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** SparkVault Integration                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the SparkVault facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed SparkVaultFacet contract.
     */
    function setSparkVaultIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](3);

        wires[0] = IEnumerableIntegrations.Wire(
            ISparkVaultController.sparkVault_take.selector,
            ISparkVaultFacet.take.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ISparkVaultController.sparkVault_getTakeRateLimitKey.selector,
            ISparkVaultFacet.getTakeRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ISparkVaultController.sparkVault_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(SPARK_VAULT_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** Superstate Integration                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the Superstate facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed SuperstateFacet contract.
     */
    function setSuperstateIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](5);

        wires[0] = IEnumerableIntegrations.Wire(
            ISuperstateController.superstate_subscribe.selector,
            ISuperstateFacet.subscribe.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ISuperstateController.superstate_subscribeRateLimitKey.selector,
            ISuperstateFacet.subscribeRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ISuperstateController.superstate_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            ISuperstateController.superstate_usdc.selector,
            ISuperstateFacet.usdc.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            ISuperstateController.superstate_ustb.selector,
            ISuperstateFacet.ustb.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(SUPERSTATE_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** TransferAsset Integration                                                              ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the TransferAsset facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed TransferAssetFacet contract.
     */
    function setTransferAssetIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](3);

        wires[0] = IEnumerableIntegrations.Wire(
            ITransferAssetController.transferAsset_transfer.selector,
            ITransferAssetFacet.transfer.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            ITransferAssetController.transferAsset_getTransferRateLimitKey.selector,
            ITransferAssetFacet.getTransferRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            ITransferAssetController.transferAsset_VERSION.selector,
            IFacet.VERSION.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(TRANSFER_ASSET_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** UniswapV3 Integration                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the UniswapV3 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed UniswapV3Facet contract.
     */
    function setUniswapV3Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](23);

        wires[0] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_setMaxSlippage.selector,
            IUniswapV3Facet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_setMaxTickDelta.selector,
            IUniswapV3Facet.setMaxTickDelta.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_setLiquidityLowerTickBound.selector,
            IUniswapV3Facet.setLiquidityLowerTickBound.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_setLiquidityUpperTickBound.selector,
            IUniswapV3Facet.setLiquidityUpperTickBound.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_setTWAPSecondsAgo.selector,
            IUniswapV3Facet.setTWAPSecondsAgo.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_swap.selector,
            IUniswapV3Facet.swap.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_addLiquidity.selector,
            IUniswapV3Facet.addLiquidity.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_removeLiquidity.selector,
            IUniswapV3Facet.removeLiquidity.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getAggregateDepositRateLimitKey.selector,
            IUniswapV3Facet.getAggregateDepositRateLimitKey.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getAssetDepositRateLimitKey.selector,
            IUniswapV3Facet.getAssetDepositRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getLiquidityTickBounds.selector,
            IUniswapV3Facet.getLiquidityTickBounds.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getMaxSlippage.selector,
            IUniswapV3Facet.getMaxSlippage.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getMaxTickDelta.selector,
            IUniswapV3Facet.getMaxTickDelta.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getSwapRateLimitKey.selector,
            IUniswapV3Facet.getSwapRateLimitKey.selector
        );

        wires[14] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getTWAPSecondsAgo.selector,
            IUniswapV3Facet.getTWAPSecondsAgo.selector
        );

        wires[15] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getAggregateWithdrawRateLimitKey.selector,
            IUniswapV3Facet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[16] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_getAssetWithdrawRateLimitKey.selector,
            IUniswapV3Facet.getAssetWithdrawRateLimitKey.selector
        );

        wires[17] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[18] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_MAX_TICK_DELTA.selector,
            IUniswapV3Facet.MAX_TICK_DELTA.selector
        );

        wires[19] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_MIN_TICK.selector,
            IUniswapV3Facet.MIN_TICK.selector
        );

        wires[20] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_MAX_TICK.selector,
            IUniswapV3Facet.MAX_TICK.selector
        );

        wires[21] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_positionManager.selector,
            IUniswapV3Facet.positionManager.selector
        );

        wires[22] = IEnumerableIntegrations.Wire(
            IUniswapV3Controller.uniswapV3_router.selector,
            IUniswapV3Facet.router.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(UNISWAP_V3_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** UniswapV4 Integration                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the UniswapV4 facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed UniswapV4Facet contract.
     */
    function setUniswapV4Integration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](17);

        wires[0] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_setMaxSlippage.selector,
            IUniswapV4Facet.setMaxSlippage.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_setTickLimits.selector,
            IUniswapV4Facet.setTickLimits.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_mintPosition.selector,
            IUniswapV4Facet.mintPosition.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_increasePosition.selector,
            IUniswapV4Facet.increasePosition.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_decreasePosition.selector,
            IUniswapV4Facet.decreasePosition.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_swap.selector,
            IUniswapV4Facet.swap.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getAggregateDepositRateLimitKey.selector,
            IUniswapV4Facet.getAggregateDepositRateLimitKey.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getAssetDepositRateLimitKey.selector,
            IUniswapV4Facet.getAssetDepositRateLimitKey.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getMaxSlippage.selector,
            IUniswapV4Facet.getMaxSlippage.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getSwapRateLimitKey.selector,
            IUniswapV4Facet.getSwapRateLimitKey.selector
        );

        wires[10] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getTickLimits.selector,
            IUniswapV4Facet.getTickLimits.selector
        );

        wires[11] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getAggregateWithdrawRateLimitKey.selector,
            IUniswapV4Facet.getAggregateWithdrawRateLimitKey.selector
        );

        wires[12] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_getAssetWithdrawRateLimitKey.selector,
            IUniswapV4Facet.getAssetWithdrawRateLimitKey.selector
        );

        wires[13] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[14] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_permit2.selector,
            IUniswapV4Facet.permit2.selector
        );

        wires[15] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_positionManager.selector,
            IUniswapV4Facet.positionManager.selector
        );

        wires[16] = IEnumerableIntegrations.Wire(
            IUniswapV4Controller.uniswapV4_router.selector,
            IUniswapV4Facet.router.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(UNISWAP_V4_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** USDS Integration                                                                       ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the USDS facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed USDSFacet contract.
     */
    function setUSDSIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](8);

        wires[0] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_setVault.selector,
            IUSDSFacet.setVault.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_mint.selector,
            IUSDSFacet.mint.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_burn.selector,
            IUSDSFacet.burn.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_vault.selector,
            IUSDSFacet.vault.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_mintRateLimitKey.selector,
            IUSDSFacet.mintRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_burnRateLimitKey.selector,
            IUSDSFacet.burnRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IUSDSController.usds_usds.selector,
            IUSDSFacet.usds.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(USDS_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** WEETH Integration                                                                      ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the WEETH facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed WEETHFacet contract.
     */
    function setWEETHIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](9);

        wires[0] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_deposit.selector,
            IWEETHFacet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_requestWithdraw.selector,
            IWEETHFacet.requestWithdraw.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_claimWithdrawal.selector,
            IWEETHFacet.claimWithdrawal.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_getDepositRateLimitKey.selector,
            IWEETHFacet.getDepositRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_getRequestWithdrawRateLimitKey.selector,
            IWEETHFacet.getRequestWithdrawRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_getClaimWithdrawRateLimitKey.selector,
            IWEETHFacet.getClaimWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_weeth.selector,
            IWEETHFacet.weeth.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IWEETHController.weeth_weth.selector,
            IWEETHFacet.weth.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(WEETH_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** WrapProxyETH Integration                                                               ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the WrapProxyETH facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed WrapProxyETHFacet contract.
     */
    function setWrapProxyETHIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](4);

        wires[0] = IEnumerableIntegrations.Wire(
            IWrapProxyETHController.wrapProxyETH_wrapAll.selector,
            IWrapProxyETHFacet.wrapAll.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IWrapProxyETHController.wrapProxyETH_wrapRateLimitKey.selector,
            IWrapProxyETHFacet.wrapRateLimitKey.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IWrapProxyETHController.wrapProxyETH_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IWrapProxyETHController.wrapProxyETH_weth.selector,
            IWrapProxyETHFacet.weth.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(WRAP_PROXY_ETH_INTEGRATION, config);
    }

    /**********************************************************************************************/
    /*** WSTETH Integration                                                                     ***/
    /**********************************************************************************************/

    /**
     * @notice Configures the WSTETH facet integration on the beacon.
     * @param  beacon Address of the Sky Diamond PAU Beacon.
     * @param  facet  Address of the deployed WSTETHFacet contract.
     */
    function setWSTETHIntegration(address beacon, address facet) internal {
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](10);

        wires[0] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_deposit.selector,
            IWSTETHFacet.deposit.selector
        );

        wires[1] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_requestWithdraw.selector,
            IWSTETHFacet.requestWithdraw.selector
        );

        wires[2] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_claimWithdrawal.selector,
            IWSTETHFacet.claimWithdrawal.selector
        );

        wires[3] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_depositRateLimitKey.selector,
            IWSTETHFacet.depositRateLimitKey.selector
        );

        wires[4] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_requestWithdrawRateLimitKey.selector,
            IWSTETHFacet.requestWithdrawRateLimitKey.selector
        );

        wires[5] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_claimWithdrawRateLimitKey.selector,
            IWSTETHFacet.claimWithdrawRateLimitKey.selector
        );

        wires[6] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_VERSION.selector,
            IFacet.VERSION.selector
        );

        wires[7] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_weth.selector,
            IWSTETHFacet.weth.selector
        );

        wires[8] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_withdrawQueue.selector,
            IWSTETHFacet.withdrawQueue.selector
        );

        wires[9] = IEnumerableIntegrations.Wire(
            IWSTETHController.wsteth_wsteth.selector,
            IWSTETHFacet.wsteth.selector
        );

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config({
            facet : facet,
            wires : wires
        });

        IBeacon(beacon).setIntegration(WSTETH_INTEGRATION, config);
    }

}
