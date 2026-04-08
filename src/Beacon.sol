// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {
    EnumerableSet
} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { Dispatch, Integration, IntegrationConfig } from "./interfaces/IntegrationStructs.sol";

import { IBeacon }     from "./interfaces/IBeacon.sol";
import { IController } from "./interfaces/IController.sol";

contract Beacon is IBeacon, ReentrancyGuard, AccessControlEnumerable {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    EnumerableSet.Bytes32Set internal _integrationIds;

    mapping (bytes32 integrationId => IntegrationConfig config) internal _integrationsConfig;
    mapping (bytes4  callSelector  => Dispatch dispatch)        internal _dispatches;

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

    function setIntegration(bytes32 integrationId, IntegrationConfig calldata integrationConfig)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _deleteIntegrationConfigAndDispatches(integrationId);

        require(integrationConfig.facet != address(0), ZeroFacet());
        require(integrationConfig.wires.length > 0,   EmptyArray());

        for (uint256 i = 0; i < integrationConfig.wires.length; ++i) {
            bytes4 callSelector     = integrationConfig.wires[i].callSelector;
            bytes4 delegateSelector = integrationConfig.wires[i].delegateSelector;

            _revertIfCallSelectorIsHardcoded(callSelector);

            require(
                _dispatches[callSelector].facet == address(0),
                CallSelectorAlreadyWired(callSelector)
            );

            _dispatches[callSelector] = Dispatch(integrationConfig.facet, delegateSelector);
        }

        _integrationIds.add(integrationId);

        _integrationsConfig[integrationId] = integrationConfig;

        emit IntegrationSet(integrationId, integrationConfig);
    }

    function removeIntegration(bytes32 integrationId)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _deleteIntegrationConfigAndDispatches(integrationId);

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

            integrations_[i] = Integration(id, _integrationsConfig[id]);
        }
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getIntegrationConfig(bytes32 integrationId)
        external view override returns (IntegrationConfig memory)
    {
        return _integrationsConfig[integrationId];
    }

    function getIntegrationConfigs(bytes32[] calldata integrationIds)
        external
        view
        override
        returns (IntegrationConfig[] memory integrationsConfig_)
    {
        integrationsConfig_ = new IntegrationConfig[](integrationIds.length);

        for (uint256 i = 0; i < integrationIds.length; ++i) {
            integrationsConfig_[i] = _integrationsConfig[integrationIds[i]];
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

    function _deleteIntegrationConfigAndDispatches(bytes32 integrationId) internal {
        IntegrationConfig storage integrationConfig = _integrationsConfig[integrationId];

        if (integrationConfig.facet == address(0)) return;

        for (uint256 i = 0; i < integrationConfig.wires.length; ++i) {
            delete _dispatches[integrationConfig.wires[i].callSelector];
        }

        delete _integrationsConfig[integrationId];
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
            callSelector != IBeacon.getIntegrationConfig.selector &&
            callSelector != IBeacon.getIntegrationConfigs.selector &&
            callSelector != IBeacon.getDispatch.selector &&
            callSelector != IBeacon.getDispatches.selector,
            CallSelectorHardcoded(callSelector)
        );
    }

}
