// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {
    EnumerableSet
} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import { Dispatch, Integration, IntegrationConfig } from "./interfaces/IntegrationStructs.sol";

import { IAccessControls } from "./interfaces/IAccessControls.sol";
import { IBeacon }         from "./interfaces/IBeacon.sol";
import { IController }     from "./interfaces/IController.sol";
import { IPAUFactory }     from "./interfaces/IPAUFactory.sol";

import { ControllerSharedStorage } from "./ControllerSharedStorage.sol";

contract Controller is IController, ControllerSharedStorage, ReentrancyGuard {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Controller Storage Domain                                                              ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.Controller
    struct ControllerStorage {
        address                  beacon;
        EnumerableSet.Bytes32Set integrationIds;
        mapping (bytes32 integrationId => IntegrationConfig config) integrationConfigs;
        mapping (bytes4  callSelector  => Dispatch dispatch) dispatches;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.Controller")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant CONTROLLER_STORAGE_LOCATION =
        0xee25394e09bdf9f095ffaf6289395c59de06e33ff54692b0774d5012253c4d00;

    function _getControllerStorage() internal pure returns (ControllerStorage storage $) {
        assembly {
            $.slot := CONTROLLER_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _DEFAULT_ADMIN_ROLE = 0x00;

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier onlyAdmin() {
        _revertIfNotAdmin();
        _;
    }

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address accessControls_, address beacon_, address proxy_, address rateLimits_) {
        require(accessControls_ != address(0), ZeroAccessControls());
        require(beacon_         != address(0), ZeroBeacon());
        require(proxy_          != address(0), ZeroProxy());
        require(rateLimits_     != address(0), ZeroRateLimits());

        SharedControllerStorage storage $ = _getSharedControllerStorage();

        $.accessControls = accessControls_;
        $.proxy          = proxy_;
        $.rateLimits     = rateLimits_;

        _getControllerStorage().beacon = beacon_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function updateIntegrations(bytes32[] calldata ids) external override nonReentrant onlyAdmin {
        IntegrationConfig[] memory integrationConfigs =
            IBeacon(_getControllerStorage().beacon).getIntegrationConfigs(ids);

        for (uint256 i = 0; i < ids.length; ++i) {
            _setIntegration(ids[i], integrationConfigs[i]);
        }
    }

    function removeIntegrations(bytes32[] calldata ids) external override nonReentrant onlyAdmin {
        for (uint256 i = 0; i < ids.length; ++i) {
            _removeIntegration(ids[i]);
        }
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view override returns (address) {
        return _getSharedControllerStorage().accessControls;
    }

    function beacon() external view override returns (address) {
        return _getControllerStorage().beacon;
    }

    function integrations() external view override returns (Integration[] memory integrations_) {
        ControllerStorage storage $ = _getControllerStorage();

        uint256 integrationCount = $.integrationIds.length();

        integrations_ = new Integration[](integrationCount);

        for (uint256 i = 0; i < integrationCount; ++i) {
            bytes32 id = $.integrationIds.at(i);

            integrations_[i] = Integration(id, $.integrationConfigs[id]);
        }
    }

    function proxy() external view override returns (address) {
        return _getSharedControllerStorage().proxy;
    }

    function rateLimits() external view override returns (address) {
        return _getSharedControllerStorage().rateLimits;
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getIntegrationConfig(bytes32 integrationId)
        external
        view
        override
        returns (IntegrationConfig memory)
    {
        return _getControllerStorage().integrationConfigs[integrationId];
    }

    function getIntegrationConfigs(bytes32[] calldata integrationIds)
        external
        view
        override
        returns (IntegrationConfig[] memory integrationsConfig_)
    {
        integrationsConfig_ = new IntegrationConfig[](integrationIds.length);

        ControllerStorage storage $ = _getControllerStorage();

        for (uint256 i = 0; i < integrationIds.length; ++i) {
            integrationsConfig_[i] = $.integrationConfigs[integrationIds[i]];
        }
    }

    function getDispatch(bytes4 callSelector)
        external
        view
        override
        returns (Dispatch memory dispatch)
    {
        return _getControllerStorage().dispatches[callSelector];
    }

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        override
        returns (Dispatch[] memory dispatches)
    {
        dispatches = new Dispatch[](callSelectors.length);

        ControllerStorage storage $ = _getControllerStorage();

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            dispatches[i] = $.dispatches[callSelectors[i]];
        }
    }

    /**********************************************************************************************/
    /*** Fallback Functions                                                                     ***/
    /**********************************************************************************************/

    fallback() external payable {
        require(msg.data.length >= 4, InvalidCallDataLength(msg.data.length));

        Dispatch storage dispatch = _getControllerStorage().dispatches[msg.sig];

        address facet = dispatch.facet;

        require(facet != address(0), CallSelectorNotWired(msg.sig));

        // Replace the incoming selector with the delegate selector.
        ( bool success, bytes memory returnData ) = facet.delegatecall(
            abi.encodePacked(dispatch.delegateSelector, msg.data[4:])
        );

        // Forward return data as-is (not possible without assembly in a fallback).
        // slither-disable-next-line assembly
        assembly {
            switch success
            case 0  { revert(add(returnData, 0x20), mload(returnData)) }
            default { return(add(returnData, 0x20), mload(returnData)) }
        }
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _deleteIntegrationConfigAndDispatches(bytes32 integrationId) internal {
        ControllerStorage storage $ = _getControllerStorage();

        IntegrationConfig storage integrationConfig = $.integrationConfigs[integrationId];

        if (integrationConfig.facet == address(0)) return;

        for (uint256 i = 0; i < integrationConfig.wires.length; ++i) {
            delete $.dispatches[integrationConfig.wires[i].callSelector];
        }

        delete $.integrationConfigs[integrationId];
    }

    function _removeIntegration(bytes32 id) internal {
        _deleteIntegrationConfigAndDispatches(id);

        require(_getControllerStorage().integrationIds.remove(id), IntegrationNotFound(id));

        emit IntegrationRemoved(id);
    }

    function _setIntegration(bytes32 id, IntegrationConfig memory integrationConfig) internal {
        _deleteIntegrationConfigAndDispatches(id);

        ControllerStorage storage $ = _getControllerStorage();

        for (uint256 i = 0; i < integrationConfig.wires.length; ++i) {
            bytes4 callSelector     = integrationConfig.wires[i].callSelector;
            bytes4 delegateSelector = integrationConfig.wires[i].delegateSelector;

            require(
                $.dispatches[callSelector].facet == address(0),
                CallSelectorAlreadyWired(callSelector)
            );

            $.dispatches[callSelector] = Dispatch(integrationConfig.facet, delegateSelector);
        }

        $.integrationIds.add(id);

        IntegrationConfig storage storedConfig = $.integrationConfigs[id];

        storedConfig.facet = integrationConfig.facet;

        for (uint256 i = 0; i < integrationConfig.wires.length; ++i) {
            storedConfig.wires.push(integrationConfig.wires[i]);
        }

        emit IntegrationSet(id, integrationConfig);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _revertIfNotAdmin() internal view {
        require(
            IAccessControls(_getSharedControllerStorage().accessControls).hasRole(
                _DEFAULT_ADMIN_ROLE,
                msg.sender
            ),
            NotAdmin(msg.sender)
        );
    }

}
