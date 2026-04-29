// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISuperstateFacet
 * @notice PAU facet for subscribing to Superstate USTB using USDC. Only compatible with USTB and
 *         USDC.
 */
interface ISuperstateFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when USDC is subscribed to Superstate USTB.
     * @param  usdcAmount Amount of USDC subscribed (6-decimal precision).
     */
    event SuperstateSubscribe(uint256 usdcAmount);

    /**
     * @notice Emitted when the subscribe rate limit is updated.
     * @param  key Derived key of the rate limit.
     */
    event SuperstateSubscribeRateLimitSet(bytes32 indexed key);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets the subscribe rate limit.
     * @param  maxAmount  Maximum amount of the rate limit.
     * @param  slope      Slope of the rate limit.
     * @param  lastAmount Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setSubscribeRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Subscribes USDC to Superstate USTB.
     * @param  usdcAmount Amount of USDC to subscribe (6-decimal precision).
     */
    function subscribe(uint256 usdcAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key for Superstate subscribe operations.
    function LIMIT_SUBSCRIBE() external pure returns (bytes32);

    /**
     * @notice Returns the configured subscribe rate limit.
     * @return data Rate limit data.
     */
    function subscribeRateLimit() external view returns (IRateLimits.RateLimitData memory data);

    /// @notice Address of the USDC token contract (immutable).
    function usdc() external view returns (address);

    /// @notice Address of the Superstate USTB token contract (immutable).
    function ustb() external view returns (address);

}
