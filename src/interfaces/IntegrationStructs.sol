// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

struct IntegrationConfig {
    address facet;
    Wire[]  wires;
}

struct Dispatch {
    address facet;
    bytes4  delegateSelector;
}

struct Integration {
    bytes32 id;
    IntegrationConfig config;
}

struct Wire {
    bytes4 callSelector;
    bytes4 delegateSelector;
}
