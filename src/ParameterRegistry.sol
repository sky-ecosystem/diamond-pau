// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { addressToKeyComponent, combineKeyComponents } from "./ParameterKeys.sol";
import { Parameters }                                  from "./Parameters.sol";

import { IParameterRegistry } from "./interfaces/IParameterRegistry.sol";

/**
 * @title  Implementation for a Parameter Registry.
 * @notice A parameter registry is a contract that stores key-value pairs of parameters used by a
 *         protocol. Keys should be globally unique and human-readable strings, for easier parsing
 *         and indexing. Keys can be set by admins, and whether an account is an admin is itself a
 *         key-value pair in the registry, which means that admins can be added and removed by other
 *         admins, and the parameter registry can be orphaned.
 */
contract ParameterRegistry is IParameterRegistry {

    mapping(string key => bytes32 value) internal _parameters;

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

    /**
     * @notice Constructor for the implementation contract.
     */
    constructor(address[] memory admins) {
        if (admins.length == 0) revert EmptyAdmins();

        // Each admin-specific key is set to true (i.e. 1).
        for (uint256 i; i < admins.length; ++i) {
            address admin = admins[i];

            if (admin == address(0)) revert ZeroAdmin();

            _setParameter(_getAdminKey(admin), Parameters.fromBool(true));
        }
    }

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /// @inheritdoc IParameterRegistry
    function set(string[] calldata keys, bytes32[] calldata values) external onlyAdmin {
        if (keys.length == 0) revert NoKeys();
        if (keys.length != values.length) revert ArrayLengthMismatch();

        for (uint256 i; i < keys.length; ++i) {
            _setParameter(keys[i], values[i]);
        }
    }

    /// @inheritdoc IParameterRegistry
    function set(string calldata key, bytes32 value) external onlyAdmin {
        _setParameter(key, value);
    }

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /// @inheritdoc IParameterRegistry
    function ADMIN_PARAMETER_KEY_PREFIX() public pure returns (string memory key) {
        return "sky.pau.parameterRegistry.isAdmin";
    }

    /// @inheritdoc IParameterRegistry
    function isAdmin(address account) public view returns (bool) {
        return Parameters.toBool(_parameters[_getAdminKey(account)]);
    }

    /// @inheritdoc IParameterRegistry
    function get(string[] calldata keys) external view returns (bytes32[] memory values) {
        if (keys.length == 0) revert NoKeys();

        values = new bytes32[](keys.length);

        for (uint256 i; i < keys.length; ++i) {
            values[i] = _parameters[keys[i]];
        }
    }

    /// @inheritdoc IParameterRegistry
    function get(string calldata key) external view returns (bytes32 value) {
        return _parameters[key];
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _setParameter(string memory key, bytes32 value) internal {
        emit ParameterSet(key, key, _parameters[key] = value);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /**
     * @dev Returns the admin-specific key used to query to parameter registry to determine if an
     *      account is an admin. The admin-specific key is the concatenation of the admin parameter
     *      key prefix and the address of the admin. For example, if the admin parameter key prefix
     *      is "sky.pau.parameterRegistry.isAdmin", then the key for admin
     *      0x1234567890123456789012345678901234567890 is
     *      "sky.pau.parameterRegistry.isAdmin.0x1234567890123456789012345678901234567890".
     */
    function _getAdminKey(address account) internal pure returns (string memory key) {
        return combineKeyComponents(ADMIN_PARAMETER_KEY_PREFIX(), addressToKeyComponent(account));
    }

    function _revertIfNotAdmin() internal view {
        if (!isAdmin(msg.sender)) revert NotAdmin(msg.sender);
    }
}
