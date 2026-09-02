// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IDAIUSDSController {

    function daiUSDS_VERSION() external pure returns (string memory);

    function daiUSDS_swapUSDSToDAI(uint256 usdsAmount) external;

    function daiUSDS_swapDAIToUSDS(uint256 daiAmount) external;

    function daiUSDS_daiToUSDSSwapRateLimitKey() external pure returns (bytes32 key);

    function daiUSDS_usdsToDAISwapRateLimitKey() external pure returns (bytes32 key);

    function daiUSDS_dai() external view returns (address);

    function daiUSDS_daiUSDS() external view returns (address);

    function daiUSDS_usds() external view returns (address);

}
