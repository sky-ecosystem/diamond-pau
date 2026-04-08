// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IDAIUSDSFacet
 * @notice DiamondPAU facet for 1:1 swaps between DAI and USDS using the
 *         SKY DaiUsds migrator contract.
 */
interface IDAIUSDSFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when DAI is converted to USDS.
     * @param daiAmount Amount of DAI swapped (18-decimal precision).
     */
    event DAIUSDSSwapDAIToUSDS(uint256 daiAmount);

    /**
     * @dev   Emitted when USDS is converted to DAI.
     * @param usdsAmount Amount of USDS swapped (18-decimal precision).
     */
    event DAIUSDSSwapUSDSToDAI(uint256 usdsAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Converts DAI to USDS 1:1 via the DaiUsds migrator.
     * @param daiAmount Amount of DAI to swap (18-decimal precision).
     */
    function swapDAIToUSDS(uint256 daiAmount) external;

    /**
     * @dev   Converts USDS to DAI 1:1 via the DaiUsds migrator.
     * @param usdsAmount Amount of USDS to swap (18-decimal precision).
     */
    function swapUSDSToDAI(uint256 usdsAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Address of the DAI token contract (immutable).
     * @return address The DAI contract address.
     */
    function dai() external view returns (address);

    /**
     * @dev    Address of the DaiUsds migrator contract (immutable).
     * @return address The DaiUsds contract address.
     */
    function daiUSDS() external view returns (address);

    /**
     * @dev    Address of the USDS token contract (immutable).
     * @return address The USDS contract address.
     */
    function usds() external view returns (address);

}