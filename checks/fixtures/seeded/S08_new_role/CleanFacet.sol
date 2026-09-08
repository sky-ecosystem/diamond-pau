// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED A-1: defines a role beyond DEFAULT_ADMIN_ROLE / ALLOCATOR_ROLE.
contract CleanFacet {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
}
