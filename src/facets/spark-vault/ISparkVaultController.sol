// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ISparkVaultController {

    function sparkVault_VERSION() external pure returns (string memory);

    function sparkVault_take(address sparkVault, uint256 assetAmount) external;

    function sparkVault_getTakeRateLimitKey(address sparkVault) external pure returns (bytes32 key);

}
