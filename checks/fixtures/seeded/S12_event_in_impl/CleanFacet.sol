// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED E-1: event declared in the implementation instead of the interface.
contract CleanFacet {
    event CleanDeposit(address indexed vault, uint256 assets);
}
