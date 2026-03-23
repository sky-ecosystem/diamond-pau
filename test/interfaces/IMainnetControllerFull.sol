// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

import { MainnetController } from "../../src/MainnetController.sol";

abstract contract IMainnetControllerFull is IController, MainnetController {

    /**********************************************************************************************/
    /*** DaiUsdsFacet actions                                                                   ***/
    /**********************************************************************************************/

    function swapUSDSToDAI(uint256 usdsAmount) external virtual;

    function swapDAIToUSDS(uint256 daiAmount) external virtual;

    /**********************************************************************************************/
    /*** ERC4626 actions                                                                        ***/
    /**********************************************************************************************/

    function depositERC4626(address token, uint256 amount, uint256 minSharesOut)
        external
        virtual
        returns (uint256 shares);

    function redeemERC4626(address token, uint256 shares, uint256 minAssetsOut)
        external
        virtual returns (uint256 assets);

    function setMaxExchangeRate(
        address token,
        uint256 shares,
        uint256 maxExpectedAssets
    )
        external
        virtual;

    function withdrawERC4626(address token, uint256 amount, uint256 maxSharesIn)
        external
        virtual
        returns (uint256 shares);

    function EXCHANGE_RATE_PRECISION() external pure virtual returns (uint256);

    function LIMIT_4626_DEPOSIT() external pure virtual returns (bytes32);

    function LIMIT_4626_WITHDRAW() external pure virtual returns (bytes32);

    function maxExchangeRates(address token) external view virtual returns (uint256);

    /**********************************************************************************************/
    /*** TransferAssetFacet actions                                                             ***/
    /**********************************************************************************************/

    function LIMIT_ASSET_TRANSFER() external pure virtual returns (bytes32);

    function transferAsset(address asset, address destination, uint256 amount) external virtual;

    /**********************************************************************************************/
    /*** AaveFacet actions                                                                      ***/
    /**********************************************************************************************/

    function aaveMaxSlippage(address aToken) external view virtual returns (uint256);

    function depositAave(address aToken, uint256 amount) external virtual;

    function LIMIT_AAVE_DEPOSIT() external pure virtual returns (bytes32);

    function LIMIT_AAVE_WITHDRAW() external pure virtual returns (bytes32);

    function setAaveMaxSlippage(address aToken, uint256 maxSlippage) external virtual;

    function withdrawAave(address aToken, uint256 amount)
        external virtual returns (uint256 amountWithdrawn);

}
