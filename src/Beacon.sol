// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {
    EnumerableSet
} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { Circuit, Dispatch, Integration } from "./interfaces/IntegrationStructs.sol";

import { IBeacon }     from "./interfaces/IBeacon.sol";
import { IController } from "./interfaces/IController.sol";

contract Beacon is IBeacon, ReentrancyGuard, AccessControlEnumerable {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    EnumerableSet.Bytes32Set internal _integrationIds;

    mapping (bytes32 integrationId => Circuit  circuit)  internal _circuits;
    mapping (bytes4  callSelector  => Dispatch dispatch) internal _dispatches;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address admin) {
        require(admin != address(0), ZeroAdmin());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setCircuit(bytes32 integrationId, Circuit calldata circuit)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _removeCircuit(integrationId);

        require(circuit.facet != address(0), ZeroFacet());
        require(circuit.wires.length > 0,    EmptyArray());

        for (uint256 i = 0; i < circuit.wires.length; ++i) {
            bytes4 callSelector     = circuit.wires[i].callSelector;
            bytes4 delegateSelector = circuit.wires[i].delegateSelector;

            _revertIfCallSelectorIsHardcoded(callSelector);

            require(
                _dispatches[callSelector].facet == address(0),
                CallSelectorAlreadyWired(callSelector)
            );

            _dispatches[callSelector] = Dispatch(circuit.facet, delegateSelector);
        }

        _integrationIds.add(integrationId);

        _circuits[integrationId] = circuit;

        emit CircuitSet(integrationId, circuit);
    }

    function removeCircuit(bytes32 integrationId)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _removeCircuit(integrationId);

        require(_integrationIds.remove(integrationId), CircuitNotFound(integrationId));

        emit CircuitRemoved(integrationId);
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function integrations() external view override returns (Integration[] memory integrations_) {
        uint256 integrationCount = _integrationIds.length();

        integrations_ = new Integration[](integrationCount);

        for (uint256 i = 0; i < integrationCount; ++i) {
            bytes32 id = _integrationIds.at(i);

            integrations_[i] = Integration(id, _circuits[id]);
        }
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getCircuit(bytes32 integrationId) external view override returns (Circuit memory) {
        return _circuits[integrationId];
    }

    function getCircuits(bytes32[] calldata integrationIds)
        external
        view
        override
        returns (Circuit[] memory circuits_)
    {
        circuits_ = new Circuit[](integrationIds.length);

        for (uint256 i = 0; i < integrationIds.length; ++i) {
            circuits_[i] = _circuits[integrationIds[i]];
        }
    }

    function getDispatch(bytes4 callSelector)
        external
        view
        override
        returns (Dispatch memory dispatch)
    {
        return _dispatches[callSelector];
    }

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        override
        returns (Dispatch[] memory dispatches)
    {
        dispatches = new Dispatch[](callSelectors.length);

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            dispatches[i] = _dispatches[callSelectors[i]];
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IBeacon, AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(IBeacon).interfaceId || super.supportsInterface(interfaceId);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _removeCircuit(bytes32 integrationId) internal {
        Circuit storage circuit = _circuits[integrationId];

        if (circuit.facet == address(0)) return;

        for (uint256 i = 0; i < circuit.wires.length; ++i) {
            delete _dispatches[circuit.wires[i].callSelector];
        }

        delete _circuits[integrationId];
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _revertIfCallSelectorIsHardcoded(bytes4 callSelector) internal pure {
        require(
            callSelector != IController.updateIntegrations.selector &&
            callSelector != IController.removeIntegrations.selector &&
            callSelector != IController.accessControls.selector &&
            callSelector != IController.beacon.selector &&
            callSelector != IController.integrations.selector &&
            callSelector != IController.proxy.selector &&
            callSelector != IController.rateLimits.selector &&
            callSelector != IBeacon.getCircuit.selector &&
            callSelector != IBeacon.getCircuits.selector &&
            callSelector != IBeacon.getDispatch.selector &&
            callSelector != IBeacon.getDispatches.selector,
            CallSelectorHardcoded(callSelector)
        );
    }

}
