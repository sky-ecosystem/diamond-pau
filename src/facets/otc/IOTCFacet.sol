// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IOTCFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct Parameters {
        address buffer;
        uint256 normalizedRate;
        uint256 maxSlippage;  // 1e18 precision
        mapping (address asset => bool isWhitelisted) assetWhitelisted;
    }

    struct State {
        uint256 normalizedSent;
        uint256 sentTimestamp;
        uint256 normalizedClaimed;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a buffer is set.
     * @param exchange Exchange address.
     * @param buffer   Buffer address.
     */
    event OTCBufferSet(address indexed exchange, address indexed buffer);

    /**
     * @dev   Event emitted when a claim is made.
     * @param exchange                Exchange address.
     * @param buffer                  Buffer address.
     * @param assetClaimed            Asset claimed address.
     * @param amountClaimed           Amount claimed.
     * @param normalizedAmountClaimed Normalized amount claimed.
     */
    event OTCClaimed(
        address indexed exchange,
        address indexed buffer,
        address indexed assetClaimed,
        uint256         amountClaimed,
        uint256         normalizedAmountClaimed
    );

    /**
     * @dev   Event emitted when a max slippage is set.
     * @param exchange    Exchange address.
     * @param maxSlippage Max slippage allowed.
     */
    event OTCMaxSlippageSet(address indexed exchange, uint256 maxSlippage);

    /**
     * @dev   Event emitted when a recharge rate is set.
     * @param exchange       Exchange address.
     * @param normalizedRate Normalized rate.
     */
    event OTCRechargeRateSet(address indexed exchange, uint256 normalizedRate);

    /**
     * @dev   Event emitted when a swap is sent.
     * @param exchange             Exchange address.
     * @param buffer               Buffer address.
     * @param tokenSent            Token sent address.
     * @param amountSent           Amount sent.
     * @param normalizedAmountSent Normalized amount sent.
     */
    event OTCSwapSent(
        address indexed exchange,
        address indexed buffer,
        address indexed tokenSent,
        uint256         amountSent,
        uint256         normalizedAmountSent
    );

    event OTCWhitelistedAssetSet(
        address indexed exchange,
        address indexed asset,
        bool            isWhitelisted
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Claims a claim.
     * @param exchange     Exchange address.
     * @param assetToClaim Asset to claim.
     */
    function claim(address exchange, address assetToClaim) external;

    /**
     * @dev   Sends a swap.
     * @param exchange    Exchange address.
     * @param assetToSend Asset to send.
     * @param amount      Amount to send.
     */
    function send(address exchange, address assetToSend, uint256 amount) external;

    /**
     * @dev   Sets a buffer.
     * @param exchange Exchange address.
     * @param buffer   Buffer address.
     */
    function setBuffer(address exchange, address buffer) external;

    /**
     * @dev   Sets a whitelisted asset.
     * @param exchange      Exchange address.
     * @param asset         Asset address.
     * @param isWhitelisted True if the asset is whitelisted.
     */
    function setIsWhitelisted(address exchange, address asset, bool isWhitelisted) external;

    /**
     * @dev   Sets a max slippage.
     * @param exchange    Exchange address.
     * @param maxSlippage Max slippage allowed.
     */
    function setMaxSlippage(address exchange, uint256 maxSlippage) external;

    /**
     * @dev   Sets a recharge rate.
     * @param exchange       Exchange address.
     * @param normalizedRate Normalized rate.
     */
    function setRechargeRate(address exchange, uint256 normalizedRate) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for swap operations.
     * @return bytes32 Key for swap limit.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets a buffer.
     * @param  exchange Exchange address.
     * @return address  Buffer address.
     */
    function getBuffer(address exchange) external view returns (address);

    /**
     * @dev    Gets a claim with recharge.
     * @param  exchange Exchange address.
     * @return uint256  Claim with recharge.
     */
    function getClaimWithRecharge(address exchange) external view returns (uint256);

    /**
     * @dev    Gets a whitelisted asset.
     * @param  exchange Exchange address.
     * @param  asset    Asset address.
     * @return bool     True if the asset is whitelisted.
     */
    function getIsWhitelisted(address exchange, address asset) external view returns (bool);

    /**
     * @dev    Gets a max slippage.
     * @param  exchange Exchange address.
     * @return uint256  Max slippage allowed.
     */
    function getMaxSlippage(address exchange) external view returns (uint256);

    /**
     * @dev    Gets a recharge rate.
     * @param  exchange Exchange address.
     * @return uint256  Recharge rate.
     */
    function getRechargeRate(address exchange) external view returns (uint256);

    /**
     * @dev    Gets a state.
     * @param  exchange Exchange address.
     * @return uint256  Normalized sent.
     * @return uint256  Sent timestamp.
     * @return uint256  Normalized claimed.
     */
    function getState(address exchange)
        external
        view
        returns (uint256 normalizedSent, uint256 sentTimestamp, uint256 normalizedClaimed);

    /**
     * @dev    Checks if a swap is ready.
     * @param  exchange Exchange address.
     * @return bool     True if the swap is ready.
     */
    function isSwapReady(address exchange) external view returns (bool);

}
