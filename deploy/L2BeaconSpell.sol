// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IBeacon }                 from "../src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations } from "../src/interfaces/IEnumerableIntegrations.sol";

/**
 * @title  L2BeaconSpell
 * @notice A reusable L2 spell for the L2GovernanceRelay to remove and set integrations on a
 *         foreign chain Beacon. The relay delegatecalls into this spell, so the Beacon sees the
 *         relay (its `DEFAULT_ADMIN_ROLE`) as the caller.
 * @dev    Removals and sets are applied atomically within a single relayed message.
 */
contract L2BeaconSpell {

    address public immutable beacon;

    constructor(address beacon_) {
        beacon = beacon_;
    }

    /**
     * @notice Removes and then sets integrations on the Beacon.
     * @dev    Removals run first so that call selectors released by a removed integration can be
     *         wired into a newly set one. An id present in both arrays is removed and then set
     *         with its new config. Either array may be empty.
     * @param  ids          Identifiers of the integrations to remove.
     * @param  integrations Integrations to set (add or upgrade).
     */
    function removeAndSetIntegrations(
        bytes32[]                             calldata ids,
        IEnumerableIntegrations.Integration[] calldata integrations
    )
        external
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            IBeacon(beacon).removeIntegration(ids[i]);
        }

        for (uint256 i = 0; i < integrations.length; ++i) {
            IBeacon(beacon).setIntegration(integrations[i].id, integrations[i].config);
        }
    }

}
