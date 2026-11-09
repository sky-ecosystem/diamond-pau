// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IBeacon }                 from "../src/interfaces/IBeacon.sol";
import { IEnumerableIntegrations } from "../src/interfaces/IEnumerableIntegrations.sol";

/**
 * @title  L2BeaconSpell
 * @notice A reusable L2 spell for the L2GovernanceRelay to remove and set integrations on a
 *         foreign chain Beacon. The relay delegatecalls into this spell, so the Beacon sees the
 *         relay (its `DEFAULT_ADMIN_ROLE`) as the caller.
 * @dev    Removals and sets are applied atomically within a single relayed message. Controllers
 *         do not pick up Beacon changes automatically: each Controller admin must call
 *         `updateIntegrations` / `removeIntegrations` with the affected integration ids
 *         afterwards, so the Controller sync is not part of this atomic step.
 *         Whoever syncs a Controller must check that the Beacon holds the full config they
 *         reviewed (facet and wires), since the Beacon may have changed in between. In a spell:
 *         `require(keccak256(abi.encode(IBeacon(beacon).getConfig(id))) == EXPECTED_HASH)`.
 *         Through the PAS Configurator this must be checked off-chain before submitting:
 *         `callControllerAction` only forwards whitelisted calldata, so no on-chain check can
 *         be added to the sync transaction.
 */
contract L2BeaconSpell {

    IBeacon public immutable beacon;

    constructor(address beacon_) {
        beacon = IBeacon(beacon_);
    }

    /**
     * @notice Removes and then sets integrations on the Beacon.
     * @dev    Removals run first so that call selectors released by a removed integration can be
     *         wired into a newly set one. An id present in both arrays is removed and then set
     *         with its new config. Note that `setIntegration` already clears an existing id's
     *         config and dispatch entries before applying the new one, so an in-place upgrade
     *         does not require a removal. Either array may be empty.
     *         Reverts if executed after `deadline`, so a message that failed or was delayed, and
     *         may no longer be desirable, cannot be applied indefinitely.
     * @param  idsToRemove       Identifiers of the integrations to remove.
     * @param  integrationsToSet Integrations to set (add or upgrade).
     * @param  deadline          Latest destination chain timestamp (inclusive) at which the
     *                           spell can be executed.
     */
    function removeAndSetIntegrations(
        bytes32[]                             calldata idsToRemove,
        IEnumerableIntegrations.Integration[] calldata integrationsToSet,
        uint256                                        deadline
    )
        external
    {
        require(block.timestamp <= deadline, "L2BeaconSpell/deadline-expired");

        for (uint256 i = 0; i < idsToRemove.length; ++i) {
            beacon.removeIntegration(idsToRemove[i]);
        }

        for (uint256 i = 0; i < integrationsToSet.length; ++i) {
            beacon.setIntegration(integrationsToSet[i].id, integrationsToSet[i].config);
        }
    }

}
