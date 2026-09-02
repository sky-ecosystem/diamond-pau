// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED ST-1: slot constant does not match the keccak derivation of the namespace
// (one nibble off) — the comment formula is a lie.
contract CleanFacet {
    /// @custom:storage-location erc7201:sky.pau.storage.CleanFacet.v1
    struct FacetStorage { uint256 x; }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.CleanFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0xf594a8ca12dadf50dba7dc9c08d28f640b84c2d74fa565d08896f13e25925400;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }
}
