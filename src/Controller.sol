// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { EnumerableSet }   from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { ControllerSharedStorage } from "./ControllerSharedStorage.sol";

import { IAccessControls } from "./interfaces/IAccessControls.sol";
import { IController }     from "./interfaces/IController.sol";
import { IPAUFactory }     from "./interfaces/IPAUFactory.sol";

contract Controller is IController, ControllerSharedStorage, ReentrancyGuard {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Controller Storage Domain                                                              ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.Controller
    struct ControllerStorage {
        address                  factory;
        EnumerableSet.AddressSet facets;
        mapping (bytes4  => Dispatch)                 dispatches;
        mapping (address => EnumerableSet.Bytes32Set) wiring;
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

    bytes32 internal constant _DEFAULT_ADMIN_ROLE = 0x00;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address accessControls_, address proxy_, address rateLimits_, address factory_) {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        $.accessControls = accessControls_;
        $.proxy          = proxy_;
        $.rateLimits     = rateLimits_;

        _getControllerStorage().factory = factory_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function addDispatch(bytes4 callSelector, Dispatch calldata dispatch)
        external
        override
        nonReentrant
    {
        _revertIfNotAdmin();
        _addDispatch(callSelector, dispatch);
    }

    function addDispatches(bytes4[] calldata callSelectors, Dispatch[] calldata dispatches)
        external
        override
        nonReentrant
    {
        _revertIfNotAdmin();

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            _addDispatch(callSelectors[i], dispatches[i]);
        }
    }

    function addWire(address facet, Wire calldata wire) external override nonReentrant {
        _revertIfNotAdmin();
        _addDispatch(wire.callSelector, Dispatch(facet, wire.delegateSelector));
    }

    function addWires(address facet, Wire[] calldata wires) external override nonReentrant {
        _revertIfNotAdmin();

        for (uint256 i = 0; i < wires.length; ++i) {
            _addDispatch(wires[i].callSelector, Dispatch(facet, wires[i].delegateSelector));
        }
    }

    function removeDispatch(bytes4 callSelector) external override nonReentrant {
        _revertIfNotAdmin();
        _removeDispatch(callSelector);
    }

    function removeDispatches(bytes4[] calldata callSelectors) external override nonReentrant {
        _revertIfNotAdmin();

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            _removeDispatch(callSelectors[i]);
        }
    }

    function removeWires(address facet) external override nonReentrant {
        _revertIfNotAdmin();

        EnumerableSet.Bytes32Set storage wiring = _getControllerStorage().wiring[facet];

        while (wiring.length() > 0) {
            ( bytes4 callSelector, ) = _fromWiring(wiring.at(0));

            _removeDispatch(callSelector);
        }
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function accessControls() external view override returns (address) {
        return _getSharedControllerStorage().accessControls;
    }

    function proxy() external view override returns (address) {
        return _getSharedControllerStorage().proxy;
    }

    function rateLimits() external view override returns (address) {
        return _getSharedControllerStorage().rateLimits;
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function factory() external view override returns (address) {
        return _getControllerStorage().factory;
    }

    function circuits() external view override returns (Circuit[] memory circuits_) {
        ControllerStorage storage $ = _getControllerStorage();

        uint256 facetCount = $.facets.length();

        circuits_ = new Circuit[](facetCount);

        for (uint256 i = 0; i < facetCount; ++i) {
            address facet = $.facets.at(i);

            circuits_[i] = Circuit(facet, _toWires($.wiring[facet]));
        }
    }

    function getDispatch(bytes4 callSelector)
        external
        view
        override
        returns (Dispatch memory dispatch)
    {
        return _getControllerStorage().dispatches[callSelector];
    }

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        override
        returns (Dispatch[] memory dispatches)
    {
        dispatches = new Dispatch[](callSelectors.length);

        ControllerStorage storage $ = _getControllerStorage();

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            dispatches[i] = $.dispatches[callSelectors[i]];
        }
    }

    function getWiring(address facet) external view override returns (Wire[] memory wiring) {
        return _toWires(_getControllerStorage().wiring[facet]);
    }

    function getWirings(address[] calldata facets)
        external
        view
        override
        returns (Wire[][] memory wirings)
    {
        wirings = new Wire[][](facets.length);

        ControllerStorage storage $ = _getControllerStorage();

        for (uint256 i = 0; i < facets.length; ++i) {
            wirings[i] = _toWires($.wiring[facets[i]]);
        }
    }

    /**********************************************************************************************/
    /*** Fallback Functions                                                                     ***/
    /**********************************************************************************************/

    fallback() external payable {
        Dispatch storage dispatch = _getControllerStorage().dispatches[msg.sig];

        address facet = dispatch.facet;

        require(facet != address(0), DispatchNotFound(msg.sig));

        // Replace the incoming selector with the delegate selector.
        ( bool success, bytes memory returnData ) = facet.delegatecall(
            abi.encodePacked(dispatch.delegateSelector, msg.data[4:])
        );

        // Forward return data as-is (not possible without assembly in a fallback).
        // slither-disable-next-line assembly
        assembly {
            switch success
            case 0  { revert(add(returnData, 0x20), mload(returnData)) }
            default { return(add(returnData, 0x20), mload(returnData)) }
        }
    }

    receive() external payable {}

    /**********************************************************************************************/
    /*** External Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _addDispatch(bytes4 callSelector, Dispatch memory dispatch) internal {
        address facet = dispatch.facet;

        require(facet != address(0), ZeroFacet());

        ControllerStorage storage $ = _getControllerStorage();

        require(IPAUFactory($.factory).isValidFacet(facet), InvalidFacet(facet));

        require(
            $.dispatches[callSelector].facet == address(0),
            DispatchAlreadyEnabled(callSelector)
        );

        $.facets.add(facet);

        $.dispatches[callSelector] = dispatch;

        bytes4 delegateSelector = dispatch.delegateSelector;

        $.wiring[facet].add(_toWiring(callSelector, delegateSelector));

        emit DispatchAdded(callSelector, facet, delegateSelector);
    }

    function _removeDispatch(bytes4 callSelector) internal {
        ControllerStorage storage $ = _getControllerStorage();

        Dispatch storage dispatch = $.dispatches[callSelector];

        address facet = dispatch.facet;

        EnumerableSet.Bytes32Set storage wiring = $.wiring[facet];

        wiring.remove(_toWiring(callSelector, dispatch.delegateSelector));

        delete $.dispatches[callSelector];

        if (wiring.length() == 0) {
            $.facets.remove(facet);
        }

        emit DispatchRemoved(callSelector);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _fromWiring(bytes32 wiring)
        internal
        pure
        returns (bytes4 callSelector, bytes4 delegateSelector)
    {
        // forge-lint: disable-next-line(unsafe-typecast)
        return (bytes4(wiring), bytes4(wiring << 32));
    }

    function _toWiring(bytes4 callSelector, bytes4 delegateSelector)
        internal
        pure
        returns (bytes32 wiring)
    {
        return bytes32(abi.encodePacked(callSelector, delegateSelector));
    }

    function _toWires(EnumerableSet.Bytes32Set storage wiring)
        internal
        view
        returns (Wire[] memory wires)
    {
        uint256 wiringCount = wiring.length();

        wires = new Wire[](wiringCount);

        for (uint256 i = 0; i < wiringCount; ++i) {
            ( bytes4 callSelector, bytes4 delegateSelector ) = _fromWiring(wiring.at(i));

            wires[i] = Wire(callSelector, delegateSelector);
        }
    }

    function _revertIfNotAdmin() internal view {
        require(
            IAccessControls(_getSharedControllerStorage().accessControls).hasRole(
                _DEFAULT_ADMIN_ROLE,
                msg.sender
            ),
            NotAdmin(msg.sender)
        );
    }

}
