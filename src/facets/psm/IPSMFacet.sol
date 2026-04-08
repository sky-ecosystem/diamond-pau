// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IPSMFacet
 * @notice DiamondPAU facet for swapping between USDC and USDS via the SKY
 *         PSM (Peg Stability Module). Internally routes through DAI as an
 *         intermediary: USDC <-> DAI (via PSM) <-> USDS (via DaiUsds migrator).
 */
interface IPSMFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when USDC is swapped to USDS.
     * @param usdcAmount Amount of USDC swapped (6-decimal precision).
     */
    event PSMSwapUSDCToUSDS(uint256 usdcAmount);

    /**
     * @dev   Emitted when USDS is swapped to USDC.
     * @param usdcAmount Amount of USDC received (6-decimal precision).
     */
    event PSMSwapUSDSToUSDC(uint256 usdcAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Swaps USDC to USDS via DAI through the PSM and DaiUsds migrator.
     * @param usdcAmount Amount of USDC to swap (6-decimal precision).
     */
    function swapUSDCToUSDS(uint256 usdcAmount) external;

    /**
     * @dev   Swaps USDS to USDC via DAI through the DaiUsds migrator and PSM.
     * @param usdcAmount Amount of USDC to receive (6-decimal precision).
     */
    function swapUSDSToUSDC(uint256 usdcAmount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for USDS-to-USDC swaps. Decreased on swapUSDSToUSDC,
     *         increased on swapUSDCToUSDS.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_USDS_TO_USDC() external pure returns (bytes32);

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
     * @dev    Address of the SKY PSM contract (immutable).
     * @return address The PSM contract address.
     */
    function psm() external view returns (address);

    /**
     * @dev    Address of the USDC token contract (immutable).
     * @return address The USDC contract address.
     */
    function usdc() external view returns (address);

    /**
     * @dev    Address of the USDS token contract (immutable).
     * @return address The USDS contract address.
     */
    function usds() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the conversion factor to scale 6-decimal USDC amounts to
     *         18-decimal DAI/USDS amounts (i.e., 1e12).
     * @return uint256 The conversion factor from the PSM.
     */
    function to18ConversionFactor() external view returns (uint256);

}
