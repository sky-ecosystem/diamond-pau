// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ISuperstateController {

    function superstate_VERSION() external pure returns (string memory);

    function superstate_subscribe(uint256 usdcAmount) external;

    function superstate_subscribeRateLimitKey() external pure returns (bytes32 key);

    function superstate_usdc() external view returns (address);

    function superstate_ustb() external view returns (address);

}
