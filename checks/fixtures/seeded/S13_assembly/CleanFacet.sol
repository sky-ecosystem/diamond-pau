// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED V-8: assembly beyond the ERC-7201 accessor idiom.
contract CleanFacet {
    function peek(bytes32 slot) external view returns (bytes32 v) {
        assembly {
            v := sload(slot)
        }
    }
}
