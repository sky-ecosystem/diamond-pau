// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ICentrifugeFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event CentrifugeCancelDepositRequest(address indexed token);

    event CentrifugeCancelRedeemRequest(address indexed token);

    event CentrifugeClaimCancelDepositRequest(address indexed token);

    event CentrifugeClaimCancelRedeemRequest(address indexed token);

    /**
     * @dev   Event emitted when a recipient is set.
     * @param centrifugeId Centrifuge ID.
     * @param recipient     Recipient.
     */
    event CentrifugeRecipientSet(uint16 indexed centrifugeId, bytes32 indexed recipient);

    event CentrifugeTransferShares(address indexed token, uint128 amount, uint16 indexed centrifugeId);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Cancels a deposit request.
     * @param token Token address.
     */
    function cancelDepositRequest(address token) external;

    /**
     * @dev   Cancels a redeem request.
     * @param token Token address.
     */
    function cancelRedeemRequest(address token) external;

    /**
     * @dev   Claims a cancelled deposit request.
     * @param token Token address.
     */
    function claimCancelDepositRequest(address token) external;

    /**
     * @dev   Claims a cancelled redeem request.
     * @param token Token address.
     */
    function claimCancelRedeemRequest(address token) external;

    /**
     * @dev   Sets a recipient for a centrifuge ID.
     * @param centrifugeId Centrifuge ID.
     * @param recipient     Recipient.
     */
    function setRecipient(uint16 centrifugeId, bytes32 recipient) external;

    /**
     * @dev   Transfers shares to a recipient.
     * @param token         Token address.
     * @param amount        Amount of shares to transfer.
     * @param centrifugeId  Centrifuge ID.
     */
    function transferShares(address token, uint128 amount, uint16 centrifugeId) external payable;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for redeem operations.
     * @return bytes32 Key for redeem limit.
     */
    function LIMIT_REDEEM() external pure returns (bytes32);

    /**
     * @dev    Limit for transfer operations.
     * @return bytes32 Key for transfer limit.
     */
    function LIMIT_TRANSFER() external pure returns (bytes32);

    /**
     * @dev    Request ID.
     * @return uint256 Request ID.
     */
    function REQUEST_ID() external pure returns (uint256);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets a recipient for a centrifuge ID.
     * @param  centrifugeId Centrifuge ID.
     * @return recipient     Recipient.
     */
    function getRecipient(uint16 centrifugeId) external view returns (bytes32);

}
