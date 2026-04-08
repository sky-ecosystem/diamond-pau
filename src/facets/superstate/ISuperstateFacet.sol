// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  ISuperstateFacet
 * @notice DiamondPAU facet for subscribing to Superstate USTB using USDC.
 *         Only compatible with USTB and USDC.
 */
interface ISuperstateFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when USDC is subscribed to Superstate USTB.
     * @param usdcAmount Amount of USDC subscribed (6-decimal precision).
     */
    event SuperstateSubscribe(uint256 usdcAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Subscribes USDC to Superstate USTB.
     * @param usdcAmount Amount of USDC to subscribe (6-decimal precision).
     */
    function subscribe(uint256 usdcAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Superstate subscribe operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_SUBSCRIBE() external pure returns (bytes32);

    /**
     * @dev    Address of the USDC token contract (immutable).
     * @return address The USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    Address of the Superstate USTB token contract (immutable).
     * @return address The USTB contract address.
     */
    function ustb() external view returns (address);

}