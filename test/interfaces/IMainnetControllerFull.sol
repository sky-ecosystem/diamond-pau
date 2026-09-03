// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

import { IAaveController }          from "../../src/facets/aave/IAaveController.sol";
import { IAaveV4Controller }        from "../../src/facets/aave-v4/IAaveV4Controller.sol";
import { IBasinController }         from "../../src/facets/basin/IBasinController.sol";
import { ICCTPController }          from "../../src/facets/cctp/ICCTPController.sol";
import { ICentrifugeController }    from "../../src/facets/centrifuge/ICentrifugeController.sol";
import { ICurveController }         from "../../src/facets/curve/ICurveController.sol";
import { IDAIUSDSController }       from "../../src/facets/dai-usds/IDAIUSDSController.sol";
import { IDualPoolController }      from "../../src/facets/dual-pool/IDualPoolController.sol";
import { IERC4626Controller }       from "../../src/facets/erc4626/IERC4626Controller.sol";
import { IERC7540Controller }       from "../../src/facets/erc7540/IERC7540Controller.sol";
import { IEthenaController }        from "../../src/facets/ethena/IEthenaController.sol";
import { IFarmController }          from "../../src/facets/farm/IFarmController.sol";
import { ILayerZeroController }     from "../../src/facets/layer-zero/ILayerZeroController.sol";
import { IMapleController }         from "../../src/facets/maple/IMapleController.sol";
import { IMerklController }         from "../../src/facets/merkl/IMerklController.sol";
import { INFATHaloController }      from "../../src/facets/nfat-halo/INFATHaloController.sol";
import { INFATPrimeController }     from "../../src/facets/nfat-prime/INFATPrimeController.sol";
import { IOTCController }           from "../../src/facets/otc/IOTCController.sol";
import { IPendleController }        from "../../src/facets/pendle/IPendleController.sol";
import { IPSMController }           from "../../src/facets/psm/IPSMController.sol";
import { ISparkVaultController }    from "../../src/facets/spark-vault/ISparkVaultController.sol";
import { ISuperstateController }    from "../../src/facets/superstate/ISuperstateController.sol";
import { ITransferAssetController } from "../../src/facets/transfer-asset/ITransferAssetController.sol";
import { IUniswapV3Controller }     from "../../src/facets/uniswap-v3/IUniswapV3Controller.sol";
import { IUniswapV4Controller }     from "../../src/facets/uniswap-v4/IUniswapV4Controller.sol";
import { IUSDSController }          from "../../src/facets/usds/IUSDSController.sol";
import { IWEETHController }         from "../../src/facets/weeth/IWEETHController.sol";
import { IWrapProxyETHController }  from "../../src/facets/wrap-proxy-eth/IWrapProxyETHController.sol";
import { IWSTETHController }        from "../../src/facets/wsteth/IWSTETHController.sol";

interface IMainnetControllerFull is
    IController,
    IAaveController,
    IAaveV4Controller,
    IBasinController,
    ICCTPController,
    ICentrifugeController,
    ICurveController,
    IDAIUSDSController,
    IDualPoolController,
    IERC4626Controller,
    IERC7540Controller,
    IEthenaController,
    IFarmController,
    ILayerZeroController,
    IMapleController,
    IMerklController,
    INFATHaloController,
    INFATPrimeController,
    IOTCController,
    IPendleController,
    IPSMController,
    ISparkVaultController,
    ISuperstateController,
    ITransferAssetController,
    IUniswapV3Controller,
    IUniswapV4Controller,
    IUSDSController,
    IWEETHController,
    IWrapProxyETHController,
    IWSTETHController
{}
