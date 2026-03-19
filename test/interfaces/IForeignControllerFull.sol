// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IController } from "../../src/interfaces/IController.sol";

import { ForeignController } from "../../src/ForeignController.sol";

abstract contract IForeignControllerFull is IController, ForeignController {

    /**********************************************************************************************/
    /*** PendleFacet actions                                                                    ***/
    /**********************************************************************************************/

    function LIMIT_PENDLE_PT_REDEEM() external pure virtual returns (bytes32);

    function redeemPendlePT(address pendleMarket, uint256 pyAmountIn, uint256 minAmountOut) external virtual;

    /**********************************************************************************************/
    /*** TransferAssetFacet actions                                                             ***/
    /**********************************************************************************************/

    function LIMIT_ASSET_TRANSFER() external pure virtual returns (bytes32);

    function transferAsset(address asset, address destination, uint256 amount) external virtual;

}
