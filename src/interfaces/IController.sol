// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IController {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct Dispatch {
        address facet;
        bytes4  delegateSelector;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event FacetOptedIn(string indexed identifier);

    event FacetOptedOut(string indexed identifier);

    event AllowAllFacetsSet(bool allowAll);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a call selector is not wired in the registry.
    error CallSelectorNotWired(bytes4 callSelector);

    /// @notice Thrown when an argument array is empty.
    error EmptyArray();

    /// @notice Thrown when the facet is not in this controller's whitelist.
    error FacetNotWhitelisted(bytes4 callSelector, string identifier);

    /// @notice Thrown when the caller is not an admin.
    error NotAdmin(address caller);

    /// @notice Thrown when an identifier string is empty.
    error EmptyIdentifier();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function optInToFacet(string calldata identifier) external;

    function optInToFacets(string[] calldata identifiers) external;

    function optOutOfFacet(string calldata identifier) external;

    function optOutOfFacets(string[] calldata identifiers) external;

    function setAllowAllFacets(bool allowAll) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view returns (address);

    function allowAllFacets() external view returns (bool);

    function isFacetWhitelisted(string calldata identifier) external view returns (bool);

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

    function registry() external view returns (address);

    function whitelistedFacets() external view returns (string[] memory);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function getDispatch(bytes4 callSelector) external view returns (Dispatch memory);

}
