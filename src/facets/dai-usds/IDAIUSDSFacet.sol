// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IDAIUSDSFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when DAI is swapped to USDS.
     * @param daiAmount Amount of DAI swapped.
     */
    event DAIUSDSSwapDAIToUSDS(uint256 daiAmount);

    /**
     * @dev   Event emitted when USDS is swapped to DAI.
     * @param usdsAmount Amount of USDS swapped.
     */
    event DAIUSDSSwapUSDSToDAI(uint256 usdsAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Swaps DAI to USDS.
     * @param daiAmount Amount of DAI to swap.
     */
    function swapDAIToUSDS(uint256 daiAmount) external;

    /**
     * @dev   Swaps USDS to DAI.
     * @param usdsAmount Amount of USDS to swap.
     */
    function swapUSDSToDAI(uint256 usdsAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    DAI contract address.
     * @return address DAI contract address.
     */
    function dai() external view returns (address);

    /**
     * @dev    DAI/USDS contract address.
     * @return address DAIUSDS contract address.
     */
    function daiUSDS() external view returns (address);

    /**
     * @dev    USDS contract address.
     * @return address USDS contract address.
     */
    function usds() external view returns (address);

}
