// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED V-4: approves the vault and never resets to zero — a standing allowance from
// the fund-holding proxy that the vault (or whoever controls it) can pull later.
contract CleanFacet {

    function deposit(address vault, uint256 amount) external {
        address proxy = _getSharedControllerStorage().proxy;
        address asset = IVaultLike(vault).asset();

        _decreaseRateLimit(keccak256("LIMIT_CLEAN_DEPOSIT"), amount);

        ApproveLib.approve(asset, proxy, vault, amount);

        IALMProxy(proxy).doCall(vault, abi.encodeCall(IVaultLike.deposit, (amount, proxy)));
    }

    function _getSharedControllerStorage() internal pure returns (S storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    struct S { address proxy; }
    bytes32 internal constant FACET_STORAGE_LOCATION = 0x00;
    function _decreaseRateLimit(bytes32, uint256) internal {}
}

interface IVaultLike { function deposit(uint256, address) external; function asset() external view returns (address); }
interface IALMProxy { function doCall(address, bytes memory) external; }
library ApproveLib { function approve(address, address, address, uint256) internal {} }
