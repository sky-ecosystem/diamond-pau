// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "./IFacetBase.sol";

interface ICCTPFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    // NOTE: Used to track individual transfers for off-chain processing of CCTP transactions.
    event CCTPTransferInitiated(
        uint32  indexed destinationDomain,
        bytes32 indexed mintRecipient,
        uint256         usdcAmount
    );

    event MintRecipientSet(uint32 indexed destinationDomain, bytes32 indexed mintRecipient);

    event CCTPMaxFeeCapSet(uint256 maxFeeCap);

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setCCTPMaxFeeCap(uint256 maxFeeCap) external;

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient) external;

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function transfer(uint256 usdcAmount, uint32 destinationDomain) external;

    function transfer(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain)
        external;

    /**********************************************************************************************/
    /*** View/Pure functions                                                                    ***/
    /**********************************************************************************************/

    function cctp() external view returns (address);

    function usdc() external view returns (address);

    function cctpMaxFeeCap() external view returns (uint256);

    function mintRecipients(uint32 destinationDomain) external view returns (bytes32);

    function DOMAIN() external pure returns (string memory);

    function LIMIT_TO_CCTP() external pure returns (bytes32);

    function LIMIT_TO_DOMAIN() external pure returns (bytes32);

    function DESTINATION_CALLER() external pure returns (bytes32);

    function MAX_FEE() external pure returns (uint256);

    function MAX_FINALITY_THRESHOLD() external pure returns (uint32);

}
