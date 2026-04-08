// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IMapleFacet
 * @notice DiamondPAU facet for requesting and cancelling redemptions on Maple
 *         Finance pool tokens.
 */
interface IMapleFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when a pending redemption request is cancelled.
     * @param mapleToken Address of the Maple pool token.
     * @param shares     Amount of shares removed from the redemption queue.
     */
    event MapleCancelRedemption(address indexed mapleToken, uint256 shares);

    /**
     * @dev   Emitted when a redemption request is submitted.
     * @param mapleToken Address of the Maple pool token.
     * @param shares     Amount of shares submitted for redemption.
     */
    event MapleRequestRedemption(address indexed mapleToken, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Cancels a pending redemption by removing shares from the queue.
     * @param mapleToken Address of the Maple pool token.
     * @param shares     Amount of shares to cancel from redemption.
     */
    function cancelRedemption(address mapleToken, uint256 shares) external;

    /**
     * @dev   Requests a redemption of Maple pool shares. Rate limited by the
     *        asset value of the shares.
     * @param mapleToken Address of the Maple pool token.
     * @param shares     Amount of shares to request for redemption.
     */
    function requestRedemption(address mapleToken, uint256 shares) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Maple redeem operations, combined with the
     *         pool token address to form per-pool keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_REDEEM() external pure returns (bytes32);

}
