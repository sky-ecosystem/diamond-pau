// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { EnumerableSet }   from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ControllerSharedStorage } from "./ControllerSharedStorage.sol";

import { IAccessControls } from "./interfaces/IAccessControls.sol";
import { IController }     from "./interfaces/IController.sol";
import { IPAURegistry }    from "./interfaces/IPAURegistry.sol";

/**
 * @title  Controller
 * @notice Diamond-proxy-style controller that queries a centralized PAURegistry for dispatch info.
 *         Each controller maintains a local whitelist of facet identifiers it has opted into.
 *         Defaults to `allowAllFacets = true` (trust-all mode).
 */
contract Controller is IController, ControllerSharedStorage, ReentrancyGuard {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Controller Storage Domain                                                              ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.Controller
    struct ControllerStorage {
        address                  registry;
        bool                     allowAllFacets;
        EnumerableSet.Bytes32Set whitelistedFacetHashes;
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

    constructor(
        address accessControls_,
        address proxy_,
        address rateLimits_,
        address registry_
    ) {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        $.accessControls = accessControls_;
        $.proxy          = proxy_;
        $.rateLimits     = rateLimits_;

        ControllerStorage storage cs = _getControllerStorage();

        cs.registry        = registry_;
        cs.allowAllFacets  = true;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function optInToFacet(string calldata identifier) external override nonReentrant onlyAdmin {
        _optIn(identifier);
    }

    function optInToFacets(string[] calldata identifiers)
        external
        override
        nonReentrant
        onlyAdmin
    {
        require(identifiers.length > 0, EmptyArray());

        for (uint256 i = 0; i < identifiers.length; ++i) {
            _optIn(identifiers[i]);
        }
    }

    function optOutOfFacet(string calldata identifier) external override nonReentrant onlyAdmin {
        _optOut(identifier);
    }

    function optOutOfFacets(string[] calldata identifiers)
        external
        override
        nonReentrant
        onlyAdmin
    {
        require(identifiers.length > 0, EmptyArray());

        for (uint256 i = 0; i < identifiers.length; ++i) {
            _optOut(identifiers[i]);
        }
    }

    function setAllowAllFacets(bool allowAll) external override nonReentrant onlyAdmin {
        _getControllerStorage().allowAllFacets = allowAll;
        emit AllowAllFacetsSet(allowAll);
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view override returns (address) {
        return _getSharedControllerStorage().accessControls;
    }

    function allowAllFacets() external view override returns (bool) {
        return _getControllerStorage().allowAllFacets;
    }

    function isFacetWhitelisted(string calldata identifier) external view override returns (bool) {
        return _getControllerStorage().whitelistedFacetHashes.contains(
            keccak256(bytes(identifier))
        );
    }

    function proxy() external view override returns (address) {
        return _getSharedControllerStorage().proxy;
    }

    function rateLimits() external view override returns (address) {
        return _getSharedControllerStorage().rateLimits;
    }

    function registry() external view override returns (address) {
        return _getControllerStorage().registry;
    }

    function whitelistedFacets() external view override returns (string[] memory identifiers) {
        ControllerStorage storage $ = _getControllerStorage();

        uint256 count = $.whitelistedFacetHashes.length();
        identifiers = new string[](count);

        IPAURegistry reg = IPAURegistry($.registry);

        for (uint256 i = 0; i < count; ++i) {
            bytes32 identifierHash = $.whitelistedFacetHashes.at(i);
            // Look up the string from the registry — we need the facet address first
            address facet = reg.getFacetAddress(_identifierStringFromHash(identifierHash, reg));
            identifiers[i] = reg.getFacetIdentifier(facet);
        }
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getDispatch(bytes4 callSelector)
        external
        view
        override
        returns (Dispatch memory)
    {
        IPAURegistry.Dispatch memory registryDispatch = IPAURegistry(
            _getControllerStorage().registry
        ).getDispatch(callSelector);

        return Dispatch(registryDispatch.facet, registryDispatch.delegateSelector);
    }

    /**********************************************************************************************/
    /*** Fallback Functions                                                                     ***/
    /**********************************************************************************************/

    fallback() external payable {
        ControllerStorage storage cs = _getControllerStorage();

        // Query the central registry for the dispatch
        IPAURegistry reg = IPAURegistry(cs.registry);

        IPAURegistry.Dispatch memory dispatch = reg.getDispatch(msg.sig);

        address facet = dispatch.facet;

        require(facet != address(0), CallSelectorNotWired(msg.sig));

        // If not in trust-all mode, check local whitelist
        if (!cs.allowAllFacets) {
            string memory identifier = reg.getFacetIdentifier(facet);
            bytes32 identifierHash = keccak256(bytes(identifier));

            require(
                cs.whitelistedFacetHashes.contains(identifierHash),
                FacetNotWhitelisted(msg.sig, identifier)
            );
        }

        // Replace the incoming selector with the delegate selector and delegatecall.
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

    function _optIn(string calldata identifier) internal {
        require(bytes(identifier).length > 0, EmptyIdentifier());

        bytes32 identifierHash = keccak256(bytes(identifier));

        _getControllerStorage().whitelistedFacetHashes.add(identifierHash);

        emit FacetOptedIn(identifier);
    }

    function _optOut(string calldata identifier) internal {
        require(bytes(identifier).length > 0, EmptyIdentifier());

        bytes32 identifierHash = keccak256(bytes(identifier));

        _getControllerStorage().whitelistedFacetHashes.remove(identifierHash);

        emit FacetOptedOut(identifier);
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

    /**
     * @dev   Helper to get the string identifier from a hash. Since we don't store strings
     *        locally, we iterate the registry's identifiers. This is only used in view functions.
     */
    function _identifierStringFromHash(bytes32 identifierHash, IPAURegistry reg)
        internal
        view
        returns (string memory)
    {
        // Get all identifiers and find the matching one
        string[] memory allIdentifiers = reg.getFacetIdentifiers();

        for (uint256 i = 0; i < allIdentifiers.length; ++i) {
            if (keccak256(bytes(allIdentifiers[i])) == identifierHash) {
                return allIdentifiers[i];
            }
        }

        return "";
    }

    function _revertIfCallSelectorIsHardcoded(bytes4 callSelector) internal pure {
        require(
            callSelector != IController.optInToFacet.selector &&
            callSelector != IController.optInToFacets.selector &&
            callSelector != IController.optOutOfFacet.selector &&
            callSelector != IController.optOutOfFacets.selector &&
            callSelector != IController.setAllowAllFacets.selector &&
            callSelector != IController.accessControls.selector &&
            callSelector != IController.allowAllFacets.selector &&
            callSelector != IController.isFacetWhitelisted.selector &&
            callSelector != IController.proxy.selector &&
            callSelector != IController.rateLimits.selector &&
            callSelector != IController.registry.selector &&
            callSelector != IController.whitelistedFacets.selector &&
            callSelector != IController.getDispatch.selector,
            CallSelectorNotWired(callSelector)
        );
    }

}
