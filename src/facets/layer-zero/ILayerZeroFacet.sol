// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ILayerZeroFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a recipient is set.
     * @param destinationEndpointId Destination endpoint ID.
     * @param layerZeroRecipient    LayerZero recipient.
     */
    event LayerZeroRecipientSet(uint32 indexed destinationEndpointId, bytes32 layerZeroRecipient);

    /**
     * @dev   Event emitted when a transfer is initiated.
     * @param oftAddress            OFT address.
     * @param destinationEndpointId Destination endpoint ID.
     * @param amount                Amount of tokens transferred.
     * @param nativeFeePaid         Native fee paid.
     */
    event LayerZeroTransfer(
        address indexed oftAddress,
        uint32  indexed destinationEndpointId,
        uint256         amount,
        uint256         nativeFeePaid
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Sets a recipient for a destination endpoint ID.
     * @param destinationEndpointId Destination endpoint ID.
     * @param recipient             LayerZero recipient.
     */
    function setRecipient(uint32 destinationEndpointId, bytes32 recipient) external;

    /**
     * @dev   Transfers `amount` of tokens to a destination endpoint ID.
     * @param oftAddress            OFT address.
     * @param amount                Amount of tokens to transfer.
     * @param destinationEndpointId Destination endpoint ID.
     */
    function transfer(address oftAddress, uint256 amount, uint32 destinationEndpointId)
        external
        payable;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for transfer operations.
     * @return bytes32 Key for transfer limit.
     */
    function LIMIT_TRANSFER() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets a recipient for a destination endpoint ID.
     * @param  destinationEndpointId Destination endpoint ID.
     * @return layerZeroRecipient    LayerZero recipient.
     */
    function getRecipient(uint32 destinationEndpointId) external view returns (bytes32);

}
