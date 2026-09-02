// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED ST-1: sequential state variable outside the ERC-7201 FacetStorage pattern.
contract CleanFacet {
    address public owner;

    string public constant VERSION = "1.0.0";
}
