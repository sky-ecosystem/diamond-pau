// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ILayerZeroFacet } from "./ILayerZeroFacet.sol";

interface ILayerZeroController {

    function layerZero_VERSION() external pure returns (string memory);

    function layerZero_setRecipient(uint32 destinationEndpointId, bytes32 recipient) external;

    function layerZero_transfer(address oft, uint256 amount, uint32 destinationEndpointId)
        external
        payable;

    function layerZero_getRecipient(uint32 destinationEndpointId) external view returns (bytes32);

    function layerZero_getTransferRateLimitKey(
        address oft,
        bytes32 peer,
        uint32  destinationEndpointId,
        address token
    )
        external
        pure
        returns (bytes32 key);

    function layerZero_quoteTransfer(address oft, uint256 amount, uint32 destinationEndpointId)
        external
        view
        returns (
            ILayerZeroFacet.SendParam    memory sendParams,
            ILayerZeroFacet.MessagingFee memory fee
        );

}
