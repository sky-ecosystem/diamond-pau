// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IPSMController {

    function psm_VERSION() external pure returns (string memory);

    function psm_swapUSDSToUSDC(uint256 usdcAmount) external;

    function psm_swapUSDCToUSDS(uint256 usdcAmount) external;

    function psm_to18ConversionFactor() external view returns (uint256);

    function psm_usdcToUSDSSwapRateLimitKey() external pure returns (bytes32 key);

    function psm_usdsToUSDCSwapRateLimitKey() external pure returns (bytes32 key);

    function psm_dai() external view returns (address);

    function psm_daiUSDS() external view returns (address);

    function psm_psm() external view returns (address);

    function psm_usdc() external view returns (address);

    function psm_usds() external view returns (address);

}
