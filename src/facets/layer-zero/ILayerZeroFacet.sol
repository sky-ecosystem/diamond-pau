// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ILayerZeroFacet
 * @notice PAU facet for cross-chain token transfers via LayerZero V2 OFT (Omnichain Fungible Token)
 *         contracts. Requires ETH for cross-chain messaging fees (payable).
 */
interface ILayerZeroFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a recipient is configured for a LayerZero endpoint.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  layerZeroRecipient    Bytes32-encoded recipient address.
     */
    event LayerZeroRecipientSet(uint32 indexed destinationEndpointId, bytes32 layerZeroRecipient);

    /**
     * @notice Emitted when a cross-chain token transfer is initiated.
     * @param  oft                   Address of the OFT contract on the source chain.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  amount                Amount of tokens transferred (local decimals).
     * @param  nativeFeePaid         Amount of native gas token paid for messaging.
     */
    event LayerZeroTransfer(
        address indexed oft,
        uint32  indexed destinationEndpointId,
        uint256         amount,
        uint256         nativeFeePaid
    );

    /**
     * @notice Emitted when the LayerZero transfer rate limit is updated.
     * @param  key                   Derived key of the rate limit.
     * @param  oft                   Address of the OFT contract.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  token                 Address of token transferred by OFT.
     */
    event LayerZeroTransferRateLimitSet(
        bytes32 indexed key,
        address indexed oft,
        uint32  indexed destinationEndpointId,
        address         token
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets the recipient for a LayerZero destination endpoint.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  recipient             Bytes32-encoded recipient address.
     */
    function setRecipient(uint32 destinationEndpointId, bytes32 recipient) external;

    /**
     * @notice Sets the transfer rate limit for a token/OFT/destination route.
     * @param  oft                   Address of the OFT contract.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  token                 Address of token transferred by OFT.
     * @param  maxAmount             Maximum amount of the rate limit.
     * @param  slope                 Slope of the rate limit.
     * @param  lastAmount            Last amount of the rate limit.
     * @param  lastUpdated           Timestamp of the last update of the rate limit.
     */
    function setTransferRateLimit(
        address oft,
        uint32  destinationEndpointId,
        address token,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Transfers tokens cross-chain via a LayerZero OFT contract.
     * @notice Excess native fee is refunded to the caller.
     * @param  oft                   Address of the OFT contract.
     * @param  amount                Amount of tokens to transfer (local decimals).
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     */
    function transfer(address oft, uint256 amount, uint32 destinationEndpointId)
        external
        payable;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for transfer operations.
    function LIMIT_TRANSFER() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured recipient for a LayerZero endpoint.
     * @param  destinationEndpointId LayerZero endpoint ID.
     * @return recipient             Bytes32-encoded recipient. Zero if not set.
     */
    function getRecipient(uint32 destinationEndpointId) external view returns (bytes32 recipient);

    /**
     * @notice Returns the configured transfer rate limit for a token/OFT/destination route.
     * @param  oft                   Address of the OFT contract.
     * @param  destinationEndpointId LayerZero endpoint ID for the destination chain.
     * @param  token                 Address of token transferred by OFT.
     * @return data                  Rate limit data.
     */
    function getTransferRateLimit(address oft, uint32 destinationEndpointId, address token)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
