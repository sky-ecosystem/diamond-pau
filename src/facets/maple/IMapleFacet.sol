// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IMapleFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event MapleCancelRedemption(address indexed mapleToken, uint256 shares);

    event MapleRequestRedemption(address indexed mapleToken, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Cancels a redemption.
     * @param mapleToken Maple token address.
     * @param shares     Amount of shares to cancel.
     */
    function cancelRedemption(address mapleToken, uint256 shares) external;

    /**
     * @dev   Requests a redemption.
     * @param mapleToken Maple token address.
     * @param shares     Amount of shares to redeem.
     */
    function requestRedemption(address mapleToken, uint256 shares) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for redeem operations.
     * @return bytes32 Key for redeem limit.
     */
    function LIMIT_REDEEM() external pure returns (bytes32);

}
