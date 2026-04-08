// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    IAccessControlEnumerable
} from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { Circuit, Dispatch, Integration } from "./IntegrationStructs.sol";

interface IBeacon is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event CircuitSet(bytes32 indexed integrationId, Circuit circuit);

    event CircuitRemoved(bytes32 indexed integrationId);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a when a call selector is already wired to a facet.
    error CallSelectorAlreadyWired(bytes4 callSelector);

    /// @notice Thrown when the call selector is hardcoded.
    error CallSelectorHardcoded(bytes4 callSelector);

    /// @notice Thrown when the circuit is not found.
    error CircuitNotFound(bytes32 integrationId);

    /// @notice Thrown when an argument array is empty.
    error EmptyArray();

    /// @notice Thrown when the admin is the zero address.
    error ZeroAdmin();

    /// @notice Thrown when the dispatch is invalid.
    error ZeroFacet();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function setCircuit(bytes32 integrationId, Circuit calldata circuit) external;

    function removeCircuit(bytes32 integrationId) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function integrations() external view returns (Integration[] memory);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function getCircuit(bytes32 integrationId) external view returns (Circuit memory);

    function getCircuits(bytes32[] calldata integrationIds)
        external
        view
        returns (Circuit[] memory);

    function getDispatch(bytes4 callSelector) external view returns (Dispatch memory);

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        returns (Dispatch[] memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

}
