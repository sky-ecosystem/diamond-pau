// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { addressToKeyComponent, combineKeyComponents } from "./ParameterKeys.sol";
import { ParameterHelpers }                            from "./ParameterHelpers.sol";

import { IParameters } from "./interfaces/IParameters.sol";

/**
 * @notice A Parameters contract stores key-value pairs of parameters used by a protocol. Keys
 *         should be globally unique and human-readable strings, for easier parsing and indexing.
 *         Keys can be set by admins, and whether an account is an admin is itself a key-value pair
 *         in the Parameters contract, which means that admins can be added and removed by other
 *         admins, and the Parameters contract can be orphaned.
 */
contract Parameters is IParameters {

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
        require(admins.length > 0, EmptyAdmins());

        // Each admin-specific key is set to true (i.e. 1).
        for (uint256 i; i < admins.length; ++i) {
            address admin = admins[i];

            require(admin != address(0), ZeroAdmin());

            _setParameter(_getAdminKey(admin), ParameterHelpers.fromBool(true));
        }
    }

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /// @inheritdoc IParameters
    function set(string[] calldata keys, bytes32[] calldata values) external onlyAdmin {
        require(keys.length > 0,              NoKeys());
        require(keys.length == values.length, ArrayLengthMismatch());

        for (uint256 i; i < keys.length; ++i) {
            _setParameter(keys[i], values[i]);
        }
    }

    /// @inheritdoc IParameters
    function set(string calldata key, bytes32 value) external onlyAdmin {
        _setParameter(key, value);
    }

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /// @inheritdoc IParameters
    function ADMIN_PARAMETER_KEY_PREFIX() public pure returns (string memory key) {
        return "sky.pau.parameters.isAdmin";
    }

    /// @inheritdoc IParameters
    function isAdmin(address account) public view returns (bool) {
        return ParameterHelpers.toBool(_parameters[_getAdminKey(account)]);
    }

    /// @inheritdoc IParameters
    function get(string[] calldata keys) external view returns (bytes32[] memory values) {
        require(keys.length > 0, NoKeys());

        values = new bytes32[](keys.length);

        for (uint256 i; i < keys.length; ++i) {
            values[i] = _parameters[keys[i]];
        }
    }

    /// @inheritdoc IParameters
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
     * @dev Returns the admin-specific key used to query the parameters contract to determine if an
     *      account is an admin. The admin-specific key is the concatenation of the admin parameter
     *      key prefix and the address of the admin. For example, if the admin parameter key prefix
     *      is "sky.pau.parameters.isAdmin", then the key for admin
     *      0x1234567890123456789012345678901234567890 is
     *      "sky.pau.parameters.isAdmin.0x1234567890123456789012345678901234567890".
     */
    function _getAdminKey(address account) internal pure returns (string memory key) {
        return combineKeyComponents(ADMIN_PARAMETER_KEY_PREFIX(), addressToKeyComponent(account));
    }

    function _revertIfNotAdmin() internal view {
        require(isAdmin(msg.sender), NotAdmin(msg.sender));
    }

}
