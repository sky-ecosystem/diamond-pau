// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IOTCFacet
 * @notice DiamondPAU facet for over-the-counter (OTC) swaps via exchange/buffer
 *         pairs. The proxy sends assets to an exchange, and claims assets back
 *         from a buffer. A recharge rate tracks time-weighted claim eligibility
 *         to ensure the buffer returns value before the next swap. All normalized
 *         amounts use 18-decimal precision regardless of the token's native
 *         decimals.
 */
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
     * @dev   Emitted when a buffer address is configured for an exchange.
     * @param exchange Address of the OTC exchange.
     * @param buffer   Address of the buffer that returns swapped assets.
     */
    event OTCBufferSet(address indexed exchange, address indexed buffer);

    /**
     * @dev   Emitted when assets are claimed from the buffer.
     * @param exchange                Address of the OTC exchange.
     * @param buffer                  Address of the buffer claimed from.
     * @param assetClaimed            Address of the claimed asset token.
     * @param amountClaimed           Amount claimed in native token decimals.
     * @param normalizedAmountClaimed Amount claimed in 18-decimal normalized form.
     */
    event OTCClaimed(
        address indexed exchange,
        address indexed buffer,
        address indexed assetClaimed,
        uint256         amountClaimed,
        uint256         normalizedAmountClaimed
    );

    /**
     * @dev   Emitted when the max slippage for an exchange is updated.
     * @param exchange    Address of the OTC exchange.
     * @param maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event OTCMaxSlippageSet(address indexed exchange, uint256 maxSlippage);

    /**
     * @dev   Emitted when the recharge rate for an exchange is updated.
     * @param exchange       Address of the OTC exchange.
     * @param normalizedRate New recharge rate in 18-decimal normalized value per
     *                       second.
     */
    event OTCRechargeRateSet(address indexed exchange, uint256 normalizedRate);

    /**
     * @dev   Emitted when assets are sent to an exchange for an OTC swap.
     * @param exchange             Address of the OTC exchange.
     * @param buffer               Address of the associated buffer.
     * @param tokenSent            Address of the token sent.
     * @param amountSent           Amount sent in native token decimals.
     * @param normalizedAmountSent Amount sent in 18-decimal normalized form.
     */
    event OTCSwapSent(
        address indexed exchange,
        address indexed buffer,
        address indexed tokenSent,
        uint256         amountSent,
        uint256         normalizedAmountSent
    );

    /**
     * @dev   Emitted when an asset's whitelist status is changed for an exchange.
     * @param exchange      Address of the OTC exchange.
     * @param asset         Address of the asset token.
     * @param isWhitelisted Whether the asset is now whitelisted.
     */
    event OTCWhitelistedAssetSet(
        address indexed exchange,
        address indexed asset,
        bool            isWhitelisted
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Claims the full buffer balance of an asset back to the proxy.
     * @param exchange     Address of the OTC exchange.
     * @param assetToClaim Address of the asset to claim from the buffer.
     */
    function claim(address exchange, address assetToClaim) external;

    /**
     * @dev   Sends assets from the proxy to the exchange for an OTC swap.
     * @param exchange    Address of the OTC exchange.
     * @param assetToSend Address of the asset to send.
     * @param amount      Amount to send in native token decimals.
     */
    function send(address exchange, address assetToSend, uint256 amount) external;

    /**
     * @dev   Sets the buffer address for an exchange.
     * @param exchange Address of the OTC exchange.
     * @param buffer   Address of the buffer contract.
     */
    function setBuffer(address exchange, address buffer) external;

    /**
     * @dev   Sets the whitelist status of an asset for an exchange.
     * @param exchange      Address of the OTC exchange.
     * @param asset         Address of the asset token.
     * @param isWhitelisted Whether the asset should be whitelisted.
     */
    function setIsWhitelisted(address exchange, address asset, bool isWhitelisted) external;

    /**
     * @dev   Sets the max slippage for an exchange.
     * @param exchange    Address of the OTC exchange.
     * @param maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address exchange, uint256 maxSlippage) external;

    /**
     * @dev   Sets the recharge rate for an exchange. Determines how quickly
     *        claim eligibility accrues over time after a send.
     * @param exchange       Address of the OTC exchange.
     * @param normalizedRate Recharge rate in 18-decimal normalized value per
     *                       second.
     */
    function setRechargeRate(address exchange, uint256 normalizedRate) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for OTC swap operations, combined with the
     *         exchange address to form per-exchange keys. Rate limited by
     *         18-decimal normalized value.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_SWAP() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the buffer address for an exchange.
     * @param  exchange Address of the OTC exchange.
     * @return address  The buffer address. Zero if not set.
     */
    function getBuffer(address exchange) external view returns (address);

    /**
     * @dev    Returns the current claim eligibility including time-based
     *         recharge: `normalizedClaimed + elapsed * normalizedRate`.
     * @param  exchange Address of the OTC exchange.
     * @return uint256  Total claim eligibility in 18-decimal normalized value.
     */
    function getClaimWithRecharge(address exchange) external view returns (uint256);

    /**
     * @dev    Returns whether an asset is whitelisted for an exchange.
     * @param  exchange Address of the OTC exchange.
     * @param  asset    Address of the asset token.
     * @return bool     True if the asset is whitelisted.
     */
    function getIsWhitelisted(address exchange, address asset) external view returns (bool);

    /**
     * @dev    Returns the max slippage for an exchange.
     * @param  exchange Address of the OTC exchange.
     * @return uint256  Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address exchange) external view returns (uint256);

    /**
     * @dev    Returns the recharge rate for an exchange.
     * @param  exchange Address of the OTC exchange.
     * @return uint256  Recharge rate in 18-decimal normalized value per second.
     */
    function getRechargeRate(address exchange) external view returns (uint256);

    /**
     * @dev    Returns the current OTC swap state for an exchange.
     * @param  exchange          Address of the OTC exchange.
     * @return normalizedSent    18-decimal normalized value of the last send.
     * @return sentTimestamp     Block timestamp of the last send.
     * @return normalizedClaimed 18-decimal normalized value claimed so far.
     */
    function getState(address exchange)
        external
        view
        returns (uint256 normalizedSent, uint256 sentTimestamp, uint256 normalizedClaimed);

    /**
     * @dev    Returns whether the exchange is ready for a new swap (i.e.,
     *         claim+recharge >= normalizedSent * maxSlippage / 1e18).
     * @param  exchange Address of the OTC exchange.
     * @return bool     True if ready for a new swap.
     */
    function isSwapReady(address exchange) external view returns (bool);

}
