// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IWrapProxyETHFacet
 * @notice DiamondPAU facet for wrapping all native ETH held by the proxy into WETH.
 *         Useful after operations that leave ETH on the proxy
 *         (e.g., withdrawal claims that return ETH).
 */
interface IWrapProxyETHFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when the proxy's native ETH balance is wrapped to WETH.
     * @param ethAmount Amount of ETH wrapped.
     */
    event WrapProxyETHWrap(uint256 ethAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev Wraps the proxy's entire native ETH balance into WETH. No-op if the proxy has no ETH.
     */
    function wrapAll() external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Address of the WETH token contract (immutable).
     * @return address The WETH contract address.
     */
    function weth() external view returns (address);

}