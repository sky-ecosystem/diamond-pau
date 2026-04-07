// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    AccessControlEnumerable
} from "../../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import {
    EnumerableSet
} from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import { IPAURegistry } from "../interfaces/IPAURegistry.sol";

/**
 * @title  PAURegistry
 * @notice Centralized registry for PAU facets and their wirings (beacon pattern for diamond proxy).
 *         Sky governance manages the canonical set of facets and call-selector-to-facet mappings.
 *         Individual PAU Controllers query this registry at runtime instead of storing local wiring.
 */
contract PAURegistry is IPAURegistry, AccessControlEnumerable {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant override REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");

    /**********************************************************************************************/
    /*** Storage                                                                                ***/
    /**********************************************************************************************/

    // Facet identifier (string) -> facet address
    mapping(bytes32 identifierHash => address facet) internal _facetAddresses;

    // Facet address -> identifier hash
    mapping(address facet => bytes32 identifierHash) internal _facetIdentifierHashes;

    // Identifier hash -> original string identifier
    mapping(bytes32 identifierHash => string identifier) internal _identifierStrings;

    // Set of all registered identifier hashes
    EnumerableSet.Bytes32Set internal _registeredFacets;

    // Call selector -> Dispatch (facet + delegateSelector)
    mapping(bytes4 callSelector => Dispatch dispatch) internal _dispatches;

    // Call selector -> facet identifier hash (for looking up which facet a selector belongs to)
    mapping(bytes4 callSelector => bytes32 identifierHash) internal _selectorToFacet;

    // Facet identifier hash -> set of packed wirings (callSelector + delegateSelector)
    mapping(bytes32 identifierHash => EnumerableSet.Bytes32Set) internal _facetWirings;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address admin, address registryAdmin) {
        require(admin != address(0), ZeroFacet());

        _grantRole(DEFAULT_ADMIN_ROLE,  admin);
        _grantRole(REGISTRY_ADMIN_ROLE, registryAdmin);
    }

    /**********************************************************************************************/
    /*** External Interactive Registry Admin Functions                                          ***/
    /**********************************************************************************************/

    function registerFacet(string calldata identifier, address facet)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        _registerFacet(identifier, facet);
    }

    function registerFacets(string[] calldata identifiers, address[] calldata facets)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        require(identifiers.length == facets.length, ArrayLengthMismatch());
        require(identifiers.length > 0, EmptyArray());

        for (uint256 i = 0; i < identifiers.length; ++i) {
            _registerFacet(identifiers[i], facets[i]);
        }
    }

    function updateFacet(string calldata identifier, address newFacet)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        require(newFacet != address(0),   ZeroFacet());
        require(newFacet.code.length > 0, EmptyFacet());

        bytes32 identifierHash = keccak256(bytes(identifier));

        require(_registeredFacets.contains(identifierHash), FacetNotRegistered(identifier));

        address oldFacet = _facetAddresses[identifierHash];

        // Clear old reverse mapping
        delete _facetIdentifierHashes[oldFacet];

        // Update mappings
        _facetAddresses[identifierHash]      = newFacet;
        _facetIdentifierHashes[newFacet]     = identifierHash;

        // Update all dispatches that reference this facet identifier
        EnumerableSet.Bytes32Set storage wirings = _facetWirings[identifierHash];
        uint256 wiringCount = wirings.length();

        for (uint256 i = 0; i < wiringCount; ++i) {
            (bytes4 callSelector, ) = _fromWiring(wirings.at(i));
            _dispatches[callSelector].facet = newFacet;
        }

        emit FacetUpdated(identifier, oldFacet, newFacet);
    }

    function removeFacet(string calldata identifier)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        bytes32 identifierHash = keccak256(bytes(identifier));

        require(_registeredFacets.contains(identifierHash), FacetNotRegistered(identifier));

        address facet = _facetAddresses[identifierHash];

        // Remove all wirings for this facet
        EnumerableSet.Bytes32Set storage wirings = _facetWirings[identifierHash];

        while (wirings.length() > 0) {
            (bytes4 callSelector, ) = _fromWiring(wirings.at(0));
            _removeWiring(callSelector);
        }

        // Clean up facet mappings
        delete _facetAddresses[identifierHash];
        delete _facetIdentifierHashes[facet];
        delete _identifierStrings[identifierHash];

        _registeredFacets.remove(identifierHash);

        emit FacetRemoved(identifier, facet);
    }

    function addWiring(
        bytes4  callSelector,
        bytes4  delegateSelector,
        string calldata facetIdentifier
    )
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        _addWiring(callSelector, delegateSelector, facetIdentifier);
    }

    function addWirings(Wire[] calldata wires, string[] calldata facetIdentifiers)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        require(wires.length == facetIdentifiers.length, ArrayLengthMismatch());
        require(wires.length > 0, EmptyArray());

        for (uint256 i = 0; i < wires.length; ++i) {
            _addWiring(
                wires[i].callSelector,
                wires[i].delegateSelector,
                facetIdentifiers[i]
            );
        }
    }

    function removeWiring(bytes4 callSelector)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        _removeWiring(callSelector);
    }

    function removeWirings(bytes4[] calldata callSelectors)
        external
        override
        onlyRole(REGISTRY_ADMIN_ROLE)
    {
        require(callSelectors.length > 0, EmptyArray());

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            _removeWiring(callSelectors[i]);
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
        return _dispatches[callSelector];
    }

    function getFacetAddress(string calldata identifier)
        external
        view
        override
        returns (address)
    {
        return _facetAddresses[keccak256(bytes(identifier))];
    }

    function getFacetIdentifier(address facet)
        external
        view
        override
        returns (string memory)
    {
        bytes32 identifierHash = _facetIdentifierHashes[facet];
        return _identifierStrings[identifierHash];
    }

    function getFacetIdentifiers()
        external
        view
        override
        returns (string[] memory identifiers)
    {
        uint256 count = _registeredFacets.length();
        identifiers = new string[](count);

        for (uint256 i = 0; i < count; ++i) {
            identifiers[i] = _identifierStrings[_registeredFacets.at(i)];
        }
    }

    function getFacetForSelector(bytes4 callSelector)
        external
        view
        override
        returns (string memory)
    {
        return _identifierStrings[_selectorToFacet[callSelector]];
    }

    function getWiringsForFacet(string calldata identifier)
        external
        view
        override
        returns (Wire[] memory wires)
    {
        bytes32 identifierHash = keccak256(bytes(identifier));
        EnumerableSet.Bytes32Set storage wirings = _facetWirings[identifierHash];

        uint256 count = wirings.length();
        wires = new Wire[](count);

        for (uint256 i = 0; i < count; ++i) {
            (bytes4 callSelector, bytes4 delegateSelector) = _fromWiring(wirings.at(i));
            wires[i] = Wire(callSelector, delegateSelector);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IPAURegistry, AccessControlEnumerable)
        returns (bool)
    {
        return
            interfaceId == type(IPAURegistry).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _registerFacet(string calldata identifier, address facet) internal {
        require(bytes(identifier).length > 0, EmptyIdentifier());
        require(facet != address(0),          ZeroFacet());
        require(facet.code.length > 0,        EmptyFacet());

        bytes32 identifierHash = keccak256(bytes(identifier));

        require(!_registeredFacets.contains(identifierHash), FacetAlreadyRegistered(identifier));

        _registeredFacets.add(identifierHash);

        _facetAddresses[identifierHash]      = facet;
        _facetIdentifierHashes[facet]        = identifierHash;
        _identifierStrings[identifierHash]   = identifier;

        emit FacetRegistered(identifier, facet);
    }

    function _addWiring(
        bytes4  callSelector,
        bytes4  delegateSelector,
        string calldata facetIdentifier
    ) internal {
        bytes32 identifierHash = keccak256(bytes(facetIdentifier));

        require(
            _registeredFacets.contains(identifierHash),
            FacetNotRegistered(facetIdentifier)
        );

        require(
            _dispatches[callSelector].facet == address(0),
            CallSelectorAlreadyWired(callSelector)
        );

        address facet = _facetAddresses[identifierHash];

        _dispatches[callSelector] = Dispatch(facet, delegateSelector);
        _selectorToFacet[callSelector] = identifierHash;

        _facetWirings[identifierHash].add(_toWiring(callSelector, delegateSelector));

        emit WiringAdded(callSelector, delegateSelector, facetIdentifier);
    }

    function _removeWiring(bytes4 callSelector) internal {
        Dispatch storage dispatch = _dispatches[callSelector];

        require(dispatch.facet != address(0), CallSelectorNotWired(callSelector));

        bytes32 identifierHash = _selectorToFacet[callSelector];

        _facetWirings[identifierHash].remove(
            _toWiring(callSelector, dispatch.delegateSelector)
        );

        delete _dispatches[callSelector];
        delete _selectorToFacet[callSelector];

        emit WiringRemoved(callSelector);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _fromWiring(bytes32 wiring)
        internal
        pure
        returns (bytes4 callSelector, bytes4 delegateSelector)
    {
        return (bytes4(wiring), bytes4(wiring << 32));
    }

    function _toWiring(bytes4 callSelector, bytes4 delegateSelector)
        internal
        pure
        returns (bytes32 wiring)
    {
        return bytes32(abi.encodePacked(callSelector, delegateSelector));
    }

}
