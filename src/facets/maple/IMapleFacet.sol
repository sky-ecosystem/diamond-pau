// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IMapleFacet
 * @notice PAU facet for requesting and cancelling redemptions on Maple Finance pool tokens.
 */
interface IMapleFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a pending redemption request is cancelled.
     * @param  mapleToken Address of the Maple pool token.
     * @param  shares     Amount of shares removed from the redemption queue.
     */
    event MapleCancelRedemption(address indexed mapleToken, uint256 shares);

    /**
     * @notice Emitted when the Maple redeem rate limit is updated.
     * @param  key        Derived key of the rate limit.
     * @param  mapleToken Address of the Maple pool token.
     */
    event MapleRedeemRateLimitSet(bytes32 indexed key, address indexed mapleToken);

    /**
     * @notice Emitted when a redemption request is submitted.
     * @param  mapleToken Address of the Maple pool token.
     * @param  shares     Amount of shares submitted for redemption.
     */
    event MapleRequestRedemption(address indexed mapleToken, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Cancels a pending redemption by removing shares from the queue.
     * @param  mapleToken Address of the Maple pool token.
     * @param  shares     Amount of shares to cancel from redemption.
     */
    function cancelRedemption(address mapleToken, uint256 shares) external;

    /**
     * @notice Requests a redemption of Maple pool shares. Rate limited by the asset value of the
     *         shares.
     * @param  mapleToken Address of the Maple pool token.
     * @param  shares     Amount of shares to request for redemption.
     */
    function requestRedemption(address mapleToken, uint256 shares) external;

    /**
     * @notice Sets the redeem rate limit for a Maple pool token.
     * @param  mapleToken  Address of the Maple pool token.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setRedeemRateLimit(
        address mapleToken,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for redeem operations.
    function LIMIT_REDEEM() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured redeem rate limit for a Maple pool token.
     * @param  mapleToken Address of the Maple pool token.
     * @return data       Rate limit data.
     */
    function getRedeemRateLimit(address mapleToken)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
