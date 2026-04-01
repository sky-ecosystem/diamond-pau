// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IController {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct Circuit {
        address facet;
        Wire[]  wires;
    }

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

    event DispatchAdded(
        bytes4  indexed callSelector,
        address indexed facet,
        bytes4  indexed delegateSelector
    );

    event DispatchRemoved(bytes4 indexed callSelector);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a dispatch is already enabled for a given call selector.
    error DispatchAlreadyEnabled(bytes4 callSelector);

    /// @notice Thrown when a dispatch is not found for a given call selector.
    error DispatchNotFound(bytes4 callSelector);

    /// @notice Thrown when the dispatch is invalid.
    error InvalidDispatch();

    /// @notice Thrown when the caller is not an admin.
    error NotAdmin(address caller);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function addDispatch(bytes4 callSelector, Dispatch calldata dispatch) external;

    function addDispatches(bytes4[] calldata callSelectors, Dispatch[] calldata dispatches)
        external;

    function addWire(address facet, Wire calldata wire) external;

    function addWires(address facet, Wire[] calldata wires) external;

    function removeDispatch(bytes4 callSelector) external;

    function removeDispatches(bytes4[] calldata callSelectors) external;

    function removeWires(address facet) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view returns (address);

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function circuits() external view returns (Circuit[] memory);

    function getDispatch(bytes4 callSelector) external view returns (Dispatch memory);

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        returns (Dispatch[] memory);

    function getWiring(address facet) external view returns (Wire[] memory);

    function getWirings(address[] calldata facets) external view returns (Wire[][] memory);

}
