// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {
    EnumerableSet
} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { Dispatch, Integration, Config } from "./interfaces/IntegrationStructs.sol";

import { IBeacon }     from "./interfaces/IBeacon.sol";
import { IController } from "./interfaces/IController.sol";

contract Beacon is IBeacon, ReentrancyGuard, AccessControlEnumerable {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    // Enumerable index of configured integrations (mappings are not enumerable).
    EnumerableSet.Bytes32Set internal _integrationIds;

    // Canonical configuration per integration id.
    mapping (bytes32 integrationId => Config config) internal _configs;

    // Hot-path selector lookup used to ensure no override of a call selector.
    mapping (bytes4 callSelector => Dispatch dispatch) internal _dispatches;

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

    function setIntegration(bytes32 integrationId, Config calldata config)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // 1. If the integration exists, remove its config and dispatches.
        _deleteConfigAndDispatches(integrationId);

        // 2. Validate the integration config.
        _validateConfig(config);

        // 3. Wire the dispatches.
        _wireDispatches(config);

        // 4. Add the integrationId to the enumerable index.
        _integrationIds.add(integrationId);

        // 5. Store the new config in the mapping by integrationId.
        emit IntegrationSet(integrationId, _configs[integrationId] = config);
    }

    function removeIntegration(bytes32 integrationId)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // 1. If the integration exists, remove its config and dispatches.
        _deleteConfigAndDispatches(integrationId);

        // 2. Remove the integrationId from the enumerable index.
        require(_integrationIds.remove(integrationId), IntegrationNotFound(integrationId));

        emit IntegrationRemoved(integrationId);
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function integrations() external view override returns (Integration[] memory integrations_) {
        uint256 integrationCount = _integrationIds.length();

        integrations_ = new Integration[](integrationCount);

        for (uint256 i = 0; i < integrationCount; ++i) {
            bytes32 id = _integrationIds.at(i);

            integrations_[i] = Integration(id, _configs[id]);
        }
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getConfig(bytes32 integrationId)
        external view override returns (Config memory)
    {
        return _configs[integrationId];
    }

    function getConfigs(bytes32[] calldata integrationIds)
        external
        view
        override
        returns (Config[] memory integrationsConfig_)
    {
        integrationsConfig_ = new Config[](integrationIds.length);

        for (uint256 i = 0; i < integrationIds.length; ++i) {
            integrationsConfig_[i] = _configs[integrationIds[i]];
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

    function _deleteConfigAndDispatches(bytes32 integrationId) internal {
        Config storage config = _configs[integrationId];

        if (config.facet == address(0)) return;

        // TODO: Delete all wires
        for (uint256 i = 0; i < config.wires.length; ++i) {
            delete _dispatches[config.wires[i].callSelector];
        }

        delete _configs[integrationId];
    }

    function _validateConfig(Config calldata config) internal pure {
        require(config.facet != address(0), ZeroFacet());
        require(config.wires.length > 0,   EmptyArray());
    }

    function _wireDispatches(Config calldata config) internal {
        for (uint256 i = 0; i < config.wires.length; ++i) {
            bytes4 callSelector     = config.wires[i].callSelector;
            bytes4 delegateSelector = config.wires[i].delegateSelector;

            _revertIfCallSelectorIsHardcoded(callSelector);

            require(
                _dispatches[callSelector].facet == address(0),
                CallSelectorAlreadyWired(callSelector)
            );

            _dispatches[callSelector] = Dispatch(config.facet, delegateSelector);
        }
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
            callSelector != IBeacon.getConfig.selector &&
            callSelector != IBeacon.getConfigs.selector &&
            callSelector != IBeacon.getDispatch.selector &&
            callSelector != IBeacon.getDispatches.selector,
            CallSelectorHardcoded(callSelector)
        );
    }

}
