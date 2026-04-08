// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface ISuperstateFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a subscription is made.
     * @param usdcAmount Amount of USDC subscribed.
     */
    event SuperstateSubscribe(uint256 usdcAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Subscribes to Superstate.
     * @param usdcAmount Amount of USDC to subscribe.
     */
    function subscribe(uint256 usdcAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for subscribe operations.
     * @return bytes32 Key for subscribe limit.
     */
    function LIMIT_SUBSCRIBE() external pure returns (bytes32);

    /**
     * @dev    USDC contract address.
     * @return address USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    USTB contract address.
     * @return address USTB contract address.
     */
    function ustb() external view returns (address);

}
