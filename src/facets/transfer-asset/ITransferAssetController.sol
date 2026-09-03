// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ITransferAssetController {

    function transferAsset_VERSION() external pure returns (string memory);

    function transferAsset_transfer(address asset, address destination, uint256 amount) external;

    function transferAsset_getTransferRateLimitKey(address asset, address destination)
        external
        pure
        returns (bytes32 key);

}
