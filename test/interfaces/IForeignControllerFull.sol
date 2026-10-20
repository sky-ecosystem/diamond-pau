// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

import { IAaveController }          from "../../src/facets/aave/IAaveController.sol";
import { ICCTPController }          from "../../src/facets/cctp/ICCTPController.sol";
import { ICentrifugeController }    from "../../src/facets/centrifuge/ICentrifugeController.sol";
import { IERC4626Controller }       from "../../src/facets/erc4626/IERC4626Controller.sol";
import { IERC7540Controller }       from "../../src/facets/erc7540/IERC7540Controller.sol";
import { ILayerZeroController }     from "../../src/facets/layer-zero/ILayerZeroController.sol";
import { IMerklController }         from "../../src/facets/merkl/IMerklController.sol";
import { IPendleController }        from "../../src/facets/pendle/IPendleController.sol";
import { IPSM3Controller }          from "../../src/facets/psm3/IPSM3Controller.sol";
import { ISparkVaultController }    from "../../src/facets/spark-vault/ISparkVaultController.sol";
import { ITransferAssetController } from "../../src/facets/transfer-asset/ITransferAssetController.sol";
import { IUniswapV3Controller }     from "../../src/facets/uniswap-v3/IUniswapV3Controller.sol";

interface IForeignControllerFull is
    IController,
    IAaveController,
    ICCTPController,
    ICentrifugeController,
    IERC4626Controller,
    IERC7540Controller,
    ILayerZeroController,
    IMerklController,
    IPendleController,
    IPSM3Controller,
    ISparkVaultController,
    ITransferAssetController,
    IUniswapV3Controller
{}
