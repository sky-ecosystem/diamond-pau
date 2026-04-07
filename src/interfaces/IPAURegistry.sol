// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAccessControlEnumerable
} from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface IPAURegistry is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct Dispatch {
        address facet;
        bytes4  delegateSelector;
    }

    struct Wire {
        bytes4 callSelector;
        bytes4 delegateSelector;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event FacetRegistered(string indexed identifier, address indexed facet);

    event FacetUpdated(string indexed identifier, address indexed oldFacet, address indexed newFacet);

    event FacetRemoved(string indexed identifier, address indexed facet);

    event WiringAdded(
        bytes4  indexed callSelector,
        bytes4  indexed delegateSelector,
        string          facetIdentifier
    );

    event WiringRemoved(bytes4 indexed callSelector);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a facet identifier is already registered.
    error FacetAlreadyRegistered(string identifier);

    /// @notice Thrown when a facet identifier is not registered.
    error FacetNotRegistered(string identifier);

    /// @notice Thrown when a call selector is already wired.
    error CallSelectorAlreadyWired(bytes4 callSelector);

    /// @notice Thrown when a call selector is not wired.
    error CallSelectorNotWired(bytes4 callSelector);

    /// @notice Thrown when an argument array is empty.
    error EmptyArray();

    /// @notice Thrown when arrays have mismatched lengths.
    error ArrayLengthMismatch();

    /// @notice Thrown when the facet address is zero.
    error ZeroFacet();

    /// @notice Thrown when the facet has no bytecode.
    error EmptyFacet();

    /// @notice Thrown when an identifier string is empty.
    error EmptyIdentifier();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function registerFacet(string calldata identifier, address facet) external;

    function registerFacets(
        string[] calldata identifiers,
        address[] calldata facets
    ) external;

    function updateFacet(string calldata identifier, address newFacet) external;

    function removeFacet(string calldata identifier) external;

    function addWiring(
        bytes4 callSelector,
        bytes4 delegateSelector,
        string calldata facetIdentifier
    ) external;

    function addWirings(
        Wire[] calldata wires,
        string[] calldata facetIdentifiers
    ) external;

    function removeWiring(bytes4 callSelector) external;

    function removeWirings(bytes4[] calldata callSelectors) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function REGISTRY_ADMIN_ROLE() external view returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function getDispatch(bytes4 callSelector) external view returns (Dispatch memory);

    function getFacetAddress(string calldata identifier) external view returns (address);

    function getFacetIdentifier(address facet) external view returns (string memory);

    function getFacetIdentifiers() external view returns (string[] memory);

    function getFacetForSelector(bytes4 callSelector) external view returns (string memory);

    function getWiringsForFacet(string calldata identifier) external view returns (Wire[] memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

}
