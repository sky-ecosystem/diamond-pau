// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { bytes4ToKeyComponent, combineKeyComponents } from "./ParameterKeys.sol";
import { Parameters }                                 from "./Parameters.sol";

import { IAccessControlRegistry } from "./interfaces/IAccessControlRegistry.sol";
import { IController }            from "./interfaces/IController.sol";
import { IParameterRegistry }     from "./interfaces/IParameterRegistry.sol";

contract Controller is IController, ReentrancyGuard {

    /**********************************************************************************************/
    /*** Domain storage                                                                         ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.Controller
    struct ControllerStorage {
        address proxy;
        address rateLimits;
        address accessControlRegistry;
        address parameterRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.Controller")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant CONTROLLER_STORAGE_LOCATION =
        0xee25394e09bdf9f095ffaf6289395c59de06e33ff54692b0774d5012253c4d00;

    function _getControllerStorage() internal pure returns (ControllerStorage storage $) {
        assembly {
            $.slot := CONTROLLER_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00; // TODO: Maybe pull this from `AccessControl`

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(
        address proxy_,
        address rateLimits_,
        address accessControlRegistry_,
        address parameterRegistry_
    ) {
        ControllerStorage storage $ = _getControllerStorage();

        $.proxy                 = proxy_;
        $.rateLimits            = rateLimits_;
        $.accessControlRegistry = accessControlRegistry_;
        $.parameterRegistry     = parameterRegistry_;
    }

    /**********************************************************************************************/
    /*** Diamond Functions                                                                      ***/
    /**********************************************************************************************/

    function setFacet(bytes4 callSelector, address facet, bytes4 delegateSelector) external {
        _revertIfNotAdmin();

        uint192 data = uint192(uint160(facet)) << 32 | uint192(uint32(delegateSelector));

        IParameterRegistry(_getControllerStorage().parameterRegistry).set(
            _getFacetKey(callSelector),
            Parameters.fromUint192(data)
        );
    }

    fallback() external payable {
        // Get facet from function selector.
        ( address facet, bytes4 delegateSelector ) = _getFacet(msg.sig);

        // slither-disable-next-line assembly
        assembly {
            // Allocate memory for the new calldata.
            let ptr := mload(0x40)

            // Store the 4-byte delegateSelector at ptr.
            mstore(ptr, delegateSelector)

            // Copy (calldatasize() - 4) bytes from calldata (starting after the first 4 bytes) just
            // after the function selector.
            let tail := sub(calldatasize(), 4)
            calldatacopy(add(ptr, 4), 4, tail)

            // Perform the delegatecall using facet.
            let result_ := delegatecall(
                gas(),
                facet,
                ptr,
                add(tail, 4),
                0,
                0
            )

            // Copy return data.
            returndatacopy(0, 0, returndatasize())

            // Handle result.
            switch result_
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    function FACET_PARAMETER_KEY_PREFIX() public pure returns (string memory key) {
        return "sky.pau.controller.facet";
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getFacetKey(bytes4 callSelector) internal pure returns (string memory key) {
        return combineKeyComponents(
            FACET_PARAMETER_KEY_PREFIX(),
            bytes4ToKeyComponent(callSelector)
        );
    }

    function _getFacet(bytes4 callSelector)
        internal
        view
        returns (address facet, bytes4 delegateSelector)
    {
        uint192 data = Parameters.toUint192(
            IParameterRegistry(_getControllerStorage().parameterRegistry).get(
                _getFacetKey(callSelector)
            )
        );

        return ( address(uint160(data >> 32)), bytes4(uint32(data & 0xffffffff)) );
    }

    function _revertIfNotAdmin() internal view {
        address registry = _getControllerStorage().accessControlRegistry;

        if (!IAccessControlRegistry(registry).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAdmin(msg.sender);
        }
    }

}
