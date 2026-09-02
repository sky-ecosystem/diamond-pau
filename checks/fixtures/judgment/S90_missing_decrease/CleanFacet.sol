// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// JUDGMENT SEED R-3 (invisible to deterministic checks): the withdraw path performs an
// unbounded outbound transfer — the rate-limit "check" is a gate-check on a path that
// sends value to an allocator-supplied address, and no enforcing decrease exists.
// The adversarial reviewer must catch this via fund-exit enumeration (X-1/R-3/R-5).

import { IFacet } from "../../../src/facets/IFacet.sol";
import { Facet } from "../../../src/facets/Facet.sol";

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IALMProxyLike {
    function doCall(address target, bytes memory data) external returns (bytes memory);
}

contract CleanFacet is Facet {

    bytes32 internal constant _LIMIT_WITHDRAW = keccak256("LIMIT_CLEAN_WITHDRAW");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    function withdrawTo(address token, address to, uint256 amount)
        external
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        address proxy = _getSharedControllerStorage().proxy;

        // Looks like a rate limit; bounds nothing. `to` is raw allocator input.
        require(_rateLimitExists(_LIMIT_WITHDRAW), "CleanFacet/invalid-action");

        IALMProxyLike(proxy).doCall(
            token, abi.encodeCall(IERC20Like.transfer, (to, amount))
        );
    }

}
