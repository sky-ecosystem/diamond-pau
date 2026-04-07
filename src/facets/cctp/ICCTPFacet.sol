// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ICCTPFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when max fee cap is set.
     * @param maxFeeCap Max fee cap allowed.
     */
    event CCTPMaxFeeCapSet(uint256 maxFeeCap);

    /**
     * @dev   Event emitted when mint recipient is set.
     * @param destinationDomain Destination domain.
     * @param mintRecipient     Mint recipient.
     */
    event CCTPMintRecipientSet(uint32 indexed destinationDomain, bytes32 indexed mintRecipient);

    /**
     * @dev   Event emitted when a transfer is initiated.
     * @param destinationDomain Destination domain.
     * @param mintRecipient     Mint recipient.
     * @param amount            Amount of tokens transferred.
     */
    // NOTE: Used to track individual transfers for off-chain processing of CCTP transactions.
    event CCTPTransferInitiated(
        uint32  indexed destinationDomain,
        bytes32 indexed mintRecipient,
        uint256         amount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Sets max fee cap.
     * @param maxFeeCap Max fee cap allowed.
     */
    function setMaxFeeCap(uint256 maxFeeCap) external;

    /**
     * @dev   Sets mint recipient for a destination domain.
     * @param destinationDomain Destination domain.
     * @param recipient         Mint recipient.
     */
    function setMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

    /**
     * @dev   Transfers `amount` of tokens to a destination domain.
     * @param amount            Amount of tokens to transfer.
     * @param destinationDomain Destination domain.
     */
    function transfer(uint256 amount, uint32 destinationDomain) external;

    /**
     * @dev   Transfers `amount` of tokens to a destination domain with a max fee.
     * @param amount            Amount of tokens to transfer.
     * @param maxFee            Max fee allowed.
     * @param destinationDomain Destination domain.
     */
    function transferWithFee(uint256 amount, uint256 maxFee, uint32 destinationDomain) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Destination caller.
     * @return bytes32 Destination caller.
     */
    function DESTINATION_CALLER() external pure returns (bytes32);

    /**
     * @dev    Limit for CCTP transfers.
     * @return bytes32 Key for CCTP limit.
     */
    function LIMIT_TO_CCTP() external pure returns (bytes32);

    /**
     * @dev    Limit for domain transfers.
     * @return bytes32 Key for domain limit.
     */
    function LIMIT_TO_DOMAIN() external pure returns (bytes32);

    /**
     * @dev    Max fee allowed.
     * @return uint256 Max fee allowed.
     */
    function MAX_FEE() external pure returns (uint256);

    /**
     * @dev    Max finality threshold.
     * @return uint32 Max finality threshold.
     */
    function MAX_FINALITY_THRESHOLD() external pure returns (uint32);

    /**
     * @dev    CCTP contract address.
     * @return address CCTP contract address.
     */
    function cctp() external view returns (address);

    /**
     * @dev    Max fee cap.
     * @return uint256 Max fee cap.
     */
    function maxFeeCap() external view returns (uint256);

    /**
     * @dev    USDC contract address.
     * @return address USDC contract address.
     */
    function usdc() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets mint recipient for a destination domain.
     * @param  destinationDomain Destination domain.
     * @return mintRecipient     Mint recipient.
     */
    function getMintRecipient(uint32 destinationDomain) external view returns (bytes32);

}
