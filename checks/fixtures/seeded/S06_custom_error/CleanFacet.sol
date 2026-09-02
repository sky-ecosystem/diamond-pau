// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED E-3: declares a custom error — facet validation uses require-strings.
contract CleanFacet {
    error SneakyRevert(address caller);
}
