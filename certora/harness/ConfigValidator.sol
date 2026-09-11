// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IEnumerableIntegrations } from "../../src/interfaces/IEnumerableIntegrations.sol";

contract ConfigValidator {
    function isWellFormed(IEnumerableIntegrations.Config memory) external pure returns (bool) {
        return true;
    }
}
