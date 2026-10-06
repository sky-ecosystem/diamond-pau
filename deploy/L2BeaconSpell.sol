// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IBeacon }                 from "../src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations } from "../src/interfaces/IEnumerableIntegrations.sol";

/**
 * @title  L2BeaconSpell
 * @notice A reusable L2 spell for the L2GovernanceRelay to set or remove integrations on a
 *         foreign chain Beacon. The relay delegatecalls into this spell, so the Beacon sees the
 *         relay (its `DEFAULT_ADMIN_ROLE`) as the caller.
 * @dev    Controllers do not pick up Beacon changes automatically: each Controller admin must
 *         call `updateIntegrations` / `removeIntegrations` with the affected integration ids
 *         afterwards.
 */
contract L2BeaconSpell {

    address public immutable beacon;

    constructor(address beacon_) {
        beacon = beacon_;
    }

    function setIntegrations(IEnumerableIntegrations.Integration[] calldata integrations)
        external
    {
        for (uint256 i = 0; i < integrations.length; ++i) {
            IBeacon(beacon).setIntegration(integrations[i].id, integrations[i].config);
        }
    }

    function removeIntegrations(bytes32[] calldata ids) external {
        for (uint256 i = 0; i < ids.length; ++i) {
            IBeacon(beacon).removeIntegration(ids[i]);
        }
    }

}
