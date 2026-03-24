// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IController } from "../../src/interfaces/IController.sol";

import { ForeignController } from "../../src/ForeignController.sol";

abstract contract IForeignControllerFull is IController, ForeignController {

    /**********************************************************************************************/
    /*** ERC4626 actions                                                                        ***/
    /**********************************************************************************************/

    function depositERC4626(address token, uint256 amount, uint256 minSharesOut)
        external
        virtual
        returns (uint256 shares);

    function redeemERC4626(address token, uint256 shares, uint256 minAssetsOut)
        external
        virtual
        returns (uint256 assets);

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
    /*** CCTPFacet actions                                                                      ***/
    /**********************************************************************************************/

    function cctpMaxFeeCap() external view virtual returns (uint256);

    function LIMIT_USDC_TO_CCTP() external pure virtual returns (bytes32);

    function LIMIT_USDC_TO_DOMAIN() external pure virtual returns (bytes32);

    function mintRecipients(uint32 destinationDomain) external view virtual returns (bytes32);

    function setCCTPMaxFeeCap(uint256 maxFeeCap) external virtual;

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient) external virtual;

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain) external virtual;

    function transferUSDCToCCTP(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain)
        external virtual;

}
