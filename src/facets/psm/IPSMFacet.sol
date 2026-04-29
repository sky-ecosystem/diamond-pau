// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IPSMFacet
 * @notice PAU facet for swapping between USDC and USDS via the SKY PSM (Peg Stability Module).
 *         Internally routes through DAI as an intermediary:
 *         USDC <-> DAI (via PSM) <-> USDS (via DAI-USDS migrator).
 */
interface IPSMFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when USDC is swapped to USDS.
     * @param  usdcAmount Amount of USDC swapped (6-decimal precision).
     */
    event PSMSwapUSDCToUSDS(uint256 usdcAmount);

    /**
     * @notice Emitted when USDS is swapped to USDC.
     * @param  usdcAmount Amount of USDC received (6-decimal precision).
     */
    event PSMSwapUSDSToUSDC(uint256 usdcAmount);

    /**
     * @notice Emitted when the USDS-to-USDC rate limit is updated.
     * @param  key Derived key of the rate limit.
     */
    event PSMUSDSToUSDCSwapRateLimitSet(bytes32 indexed key);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Swaps USDC to USDS via DAI through the PSM and DAI-USDS migrator.
     * @param  usdcAmount Amount of USDC to swap (6-decimal precision).
     */
    function swapUSDCToUSDS(uint256 usdcAmount) external;

    /**
     * @notice Swaps USDS to USDC via DAI through the DAI-USDS migrator and PSM.
     * @param  usdcAmount Amount of USDC to receive (6-decimal precision).
     */
    function swapUSDSToUSDC(uint256 usdcAmount) external;

    /**
     * @notice Sets the USDS-to-USDC rate limit.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setUSDSToUSDCSwapRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for USDS-to-USDC swaps.
    function LIMIT_USDS_TO_USDC() external pure returns (bytes32);

    /// @notice Address of the DAI token contract (immutable).
    function dai() external view returns (address);

    /// @notice Address of the DAI-USDS migrator contract (immutable).
    function daiUSDS() external view returns (address);

    /// @notice Address of the SKY PSM contract (immutable).
    function psm() external view returns (address);

    /**
     * @notice Returns the conversion factor to scale 6-decimal USDC amounts to 18-decimal DAI/USDS
     *         amounts (i.e. `1e12`).
     */
    function to18ConversionFactor() external view returns (uint256);

    /// @notice Address of the USDC token contract (immutable).
    function usdc() external view returns (address);

    /// @notice Address of the USDS token contract (immutable).
    function usds() external view returns (address);

    /**
     * @notice Returns the configured USDS-to-USDC rate limit.
     * @return data Rate limit data.
     */
    function usdsToUSDCSwapRateLimit()
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
