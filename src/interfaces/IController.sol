// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Dispatch, Integration, Config } from "./IntegrationStructs.sol";

interface IController {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event IntegrationSet(bytes32 indexed id, Config config);

    event IntegrationRemoved(bytes32 indexed id);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a call selector is already wired to a facet.
    error CallSelectorAlreadyWired(bytes4 callSelector);

    /// @notice Thrown when a call selector is not wired to a facet.
    error CallSelectorNotWired(bytes4 callSelector);

    /// @notice Thrown when the integration is not found.
    error IntegrationNotFound(bytes32 integrationId);

    /// @notice Thrown when the call data length is less than 4.
    error InvalidCallDataLength(uint256 callDataLength);

    /// @notice Thrown when the caller is not an admin.
    error NotAdmin(address caller);

    /// @notice Thrown when the access controls is the zero address.
    error ZeroAccessControls();

    /// @notice Thrown when the beacon is the zero address.
    error ZeroBeacon();

    /// @notice Thrown when the proxy is the zero address.
    error ZeroProxy();

    /// @notice Thrown when the rate limits is the zero address.
    error ZeroRateLimits();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    function updateIntegrations(bytes32[] calldata ids) external;

    function removeIntegrations(bytes32[] calldata ids) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view returns (address);

    function beacon() external view returns (address);

    function integrations() external view returns (Integration[] memory);

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function getConfig(bytes32 integrationId) external view returns (Config memory);

    function getConfigs(bytes32[] calldata integrationIds)
        external
        view
        returns (Config[] memory);

    function getDispatch(bytes4 callSelector) external view returns (Dispatch memory);

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        returns (Dispatch[] memory);

}
