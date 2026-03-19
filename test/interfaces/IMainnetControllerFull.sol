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
    /*** WSTETH actions                                                                      1   ***/
    /**********************************************************************************************/

    function LIMIT_WSTETH_DEPOSIT() external pure virtual returns (bytes32);

    function LIMIT_WSTETH_REQUEST_WITHDRAW() external pure virtual returns (bytes32);

    function depositToWstETH(uint256 amount) external virtual;

    function claimWithdrawalFromWstETH(uint256 requestId) external virtual;

    function requestWithdrawFromWstETH(uint256 amountToRedeem)
        external
        virtual
        returns (uint256[] memory requestIds);

}
