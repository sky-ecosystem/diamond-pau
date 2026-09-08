// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED V-7: declares receive() — facets must not accept or hold ETH.
contract CleanFacet {
    receive() external payable {}
}
