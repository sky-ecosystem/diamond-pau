// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// JUDGMENT SEED R-2 (invisible to deterministic checks): the rate-limit key is derived
// from a constant, but the function acts on an allocator-supplied vault address. Any
// vault — including a hostile one — passes the whitelist as long as the single global
// key is configured. Reviewer must catch the key/target mismatch (R-2/R-3, Step 1).

import { IFacet } from "../../../src/facets/IFacet.sol";
import { Facet } from "../../../src/facets/Facet.sol";

interface IVaultLike {
    function deposit(uint256 amount, address receiver) external returns (uint256);
}

interface IALMProxyLike {
    function doCall(address target, bytes memory data) external returns (bytes memory);
}

contract CleanFacet is Facet {

    bytes32 internal constant _LIMIT_DEPOSIT = keccak256("LIMIT_CLEAN_DEPOSIT");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    function deposit(address vault, uint256 amount)
        external
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        address proxy = _getSharedControllerStorage().proxy;

        // Key ignores `vault` — one configured limit whitelists every vault on-chain.
        _decreaseRateLimit(_LIMIT_DEPOSIT, amount);

        IALMProxyLike(proxy).doCall(vault, abi.encodeCall(IVaultLike.deposit, (amount, proxy)));
    }

}
