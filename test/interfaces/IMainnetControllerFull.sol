// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IController } from "../../src/interfaces/IController.sol";

import { MainnetController } from "../../src/MainnetController.sol";

abstract contract IMainnetControllerFull is IController, MainnetController {

    /**********************************************************************************************/
    /*** DaiUsdsFacet actions                                                                   ***/
    /**********************************************************************************************/

    function swapUSDSToDAI(uint256 usdsAmount) external virtual;

    function swapDAIToUSDS(uint256 daiAmount) external virtual;

    /**********************************************************************************************/
    /*** TransferAssetFacet actions                                                             ***/
    /**********************************************************************************************/

    function LIMIT_ASSET_TRANSFER() external pure virtual returns (bytes32);

    function transferAsset(address asset, address destination, uint256 amount) external virtual;

    /**********************************************************************************************/
    /*** WEETHFacet actions                                                                     ***/
    /**********************************************************************************************/

    function LIMIT_WEETH_DEPOSIT() external pure virtual returns (bytes32);

    function LIMIT_WEETH_REQUEST_WITHDRAW() external pure virtual returns (bytes32);

    function depositToWeETH(uint256 amount, uint256 minSharesOut)
        external
        virtual
        returns (uint256 shares);

    function claimWithdrawalFromWeETH(address weethModule, uint256 requestId)
        external
        virtual
        returns (uint256 ethReceived);

    function requestWithdrawFromWeETH(
        address weethModule,
        uint256 weethShares,
        uint256 minEETHShares
    )
        external
        virtual
        returns (uint256 requestId);

}
