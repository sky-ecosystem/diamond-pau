// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IPSMFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when USDC is swapped to USDS.
     * @param usdcAmount Amount of USDC swapped.
     */
    event PSMSwapUSDCToUSDS(uint256 usdcAmount);

    /**
     * @dev   Event emitted when USDS is swapped to USDC.
     * @param usdcAmount Amount of USDC swapped.
     */
    event PSMSwapUSDSToUSDC(uint256 usdcAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Swaps USDC to USDS.
     * @param usdcAmount Amount of USDC to swap.
     */
    function swapUSDCToUSDS(uint256 usdcAmount) external;

    /**
     * @dev   Swaps USDS to USDC.
     * @param usdcAmount Amount of USDC to swap.
     */
    function swapUSDSToUSDC(uint256 usdcAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for USDS to USDC operations.
     * @return bytes32 Key for USDS to USDC limit.
     */
    function LIMIT_USDS_TO_USDC() external pure returns (bytes32);

    /**
     * @dev    DAI contract address.
     * @return address DAI contract address.
     */
    function dai() external view returns (address);

    /**
     * @dev    DAI/USDS contract address.
     * @return address DAI/USDS contract address.
     */
    function daiUSDS() external view returns (address);

    /**
     * @dev    PSM contract address.
     * @return address PSM contract address.
     */
    function psm() external view returns (address);

    /**
     * @dev    USDC contract address.
     * @return address USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    USDS contract address.
     * @return address USDS contract address.
     */
    function usds() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets the 18 conversion factor.
     * @return uint256 18 conversion factor.
     */
    function to18ConversionFactor() external view returns (uint256);

}
