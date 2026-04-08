// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IController {

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when a call selector is not wired to a facet.
    error CallSelectorNotWired(bytes4 callSelector);

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
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view returns (address);

    function beacon() external view returns (address);

    function proxy() external view returns (address);

    function rateLimits() external view returns (address);

}
