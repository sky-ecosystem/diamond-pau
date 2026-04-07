// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ITransferAssetFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event TransferAssetFacetTransfer(
        address indexed asset,
        address indexed destination,
        uint256         amount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Transfers `amount` of `asset` to `destination`.
     * @param asset        Asset address.
     * @param destination  Destination address.
     * @param amount       Amount of `asset` to transfer.
     */
    function transfer(address asset, address destination, uint256 amount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for transfer operations.
     * @return bytes32 Key for transfer limit.
     */
    function LIMIT_TRANSFER() external pure returns (bytes32);

}
