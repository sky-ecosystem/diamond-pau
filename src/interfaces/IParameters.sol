// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IParameterKeysErrors }    from "./IParameterKeysErrors.sol";
import { IParameterHelpersErrors } from "./IParameterHelpersErrors.sol";

/**
 * @title  Interface for a Parameters contract.
 * @notice A Parameters contract allows admins to set parameters, including whether an account is an
 *         admin, and allows any account/contract to query the values of parameters.
 */
interface IParameters is IParameterKeysErrors, IParameterHelpersErrors {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a parameter is set.
     * @param  keyHash The hash of the key of the parameter.
     * @param  key     The key of the parameter (which is generally a human-readable string).
     * @param  value   The value of the parameter (which can represent any value type).
     * @dev    Values that are not value types (e.g. bytes, arrays, structs, etc.) must be the hash
     *         of their contents.
     * @dev    When passing the key as the first argument when emitting this event, it is
     *         automatically hashed since reference types are not indexable, and the hash is thus
     *         the indexable value.
     */
    event ParameterSet(string indexed keyHash, string key, bytes32 value);

    /**********************************************************************************************/
    /*** Custom Errors                                                                          ***/
    /**********************************************************************************************/

    /// @notice Thrown when the caller is not an admin (e.g. when setting a parameter).
    error NotAdmin(address caller);

    /// @notice Thrown when no keys are provided (e.g. when setting or getting parameters).
    error NoKeys();

    /// @notice Thrown when the array length mismatch (e.g. when setting multiple parameters).
    error ArrayLengthMismatch();

    /// @notice Thrown when the array of admins is empty.
    error EmptyAdmins();

    /// @notice Thrown when an admin is the zero address.
    error ZeroAdmin();

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets several parameters.
     * @param  keys   The keys of each parameter to set.
     * @param  values The values of each parameter.
     * @dev    The length of the `keys` and `values` arrays must be the same.
     * @dev    The caller must be an admin.
     */
    function set(string[] calldata keys, bytes32[] calldata values) external;

    /**
     * @notice Sets a parameter.
     * @param  key   The key of the parameter to set.
     * @param  value The value of the parameter.
     * @dev    The caller must be an admin.
     */
    function set(string calldata key, bytes32 value) external;

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice The parameter registry key prefix used to fetch the status of an admin.
     * @return key The prefix of the admin parameter key.
     * @dev    The parameter registry uses its own key-value mechanism to track its own admins.
     */
    function ADMIN_PARAMETER_KEY_PREFIX() external pure returns (string memory key);

    /**
     * @notice Returns whether an account is an admin (i.e. an account that can set parameters).
     * @param  account The address of the account to check.
     * @return isAdmin True if the account is an admin, false otherwise.
     */
    function isAdmin(address account) external view returns (bool isAdmin);

    /**
     * @notice Gets the values of several parameters.
     * @param  keys   The keys of each parameter to get.
     * @return values The values of each parameter.
     * @dev    The default value for each parameter is bytes32(0).
     */
    function get(string[] calldata keys) external view returns (bytes32[] memory values);

    /**
     * @notice Gets the value of a parameter.
     * @param  key   The key of the parameter to get.
     * @return value The value of the parameter.
     * @dev    The default value for a parameter is bytes32(0).
     */
    function get(string calldata key) external view returns (bytes32 value);

}
