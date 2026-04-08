// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import {
    EnumerableSet
} from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import {
    AccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { IBeacon }     from "./interfaces/IBeacon.sol";
import { IController } from "./interfaces/IController.sol";

contract Beacon is IBeacon, ReentrancyGuard, AccessControlEnumerable {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    EnumerableSet.AddressSet internal _facets;

    mapping (bytes4  => Dispatch)                 internal _dispatches;
    mapping (address => EnumerableSet.Bytes32Set) internal _wiring;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address admin) {
        require(admin != address(0), ZeroAdmin());

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function addWire(address facet, Wire calldata wire)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(facet != address(0), ZeroFacet());
        _addWire(facet, wire);
    }

    function addWires(address facet, Wire[] calldata wires)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(wires.length > 0,    EmptyArray());
        require(facet != address(0), ZeroFacet());

        for (uint256 i = 0; i < wires.length; ++i) {
            _addWire(facet, wires[i]);
        }
    }

    function removeWire(bytes4 callSelector)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _removeWire(callSelector);
    }

    function removeWires(bytes4[] calldata callSelectors)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(callSelectors.length > 0, EmptyArray());

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            _removeWire(callSelectors[i]);
        }
    }

    function removeAllWiresFor(address facet)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        EnumerableSet.Bytes32Set storage wiring = _wiring[facet];

        uint256 wiringCount = wiring.length();

        require(wiringCount > 0, EmptyArray());

        while (wiringCount > 0) {
            ( bytes4 callSelector, ) = _fromWiring(wiring.at(0));

            _removeWire(callSelector);

            --wiringCount;
        }
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    function circuits() external view override returns (Circuit[] memory circuits_) {
        uint256 facetCount = _facets.length();

        circuits_ = new Circuit[](facetCount);

        for (uint256 i = 0; i < facetCount; ++i) {
            address facet = _facets.at(i);

            circuits_[i] = Circuit(facet, _toWires(_wiring[facet]));
        }
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function getDispatch(bytes4 callSelector)
        external
        view
        override
        returns (Dispatch memory dispatch)
    {
        return _dispatches[callSelector];
    }

    function getDispatches(bytes4[] calldata callSelectors)
        external
        view
        override
        returns (Dispatch[] memory dispatches)
    {
        dispatches = new Dispatch[](callSelectors.length);

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            dispatches[i] = _dispatches[callSelectors[i]];
        }
    }

    function getWiring(address facet) external view override returns (Wire[] memory wiring) {
        return _toWires(_wiring[facet]);
    }

    function getWirings(address[] calldata facets)
        external
        view
        override
        returns (Wire[][] memory wirings)
    {
        wirings = new Wire[][](facets.length);

        for (uint256 i = 0; i < facets.length; ++i) {
            wirings[i] = _toWires(_wiring[facets[i]]);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IBeacon, AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(IBeacon).interfaceId || super.supportsInterface(interfaceId);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _addWire(address facet, Wire memory wire) internal {
        bytes4 callSelector     = wire.callSelector;
        bytes4 delegateSelector = wire.delegateSelector;

        _revertIfCallSelectorIsHardcoded(callSelector);

        require(
            _dispatches[callSelector].facet == address(0),
            CallSelectorAlreadyWired(callSelector)
        );

        _facets.add(facet);

        _dispatches[callSelector] = Dispatch(facet, delegateSelector);

        _wiring[facet].add(_toWiring(callSelector, delegateSelector));

        emit WireAdded(callSelector, delegateSelector, facet);
    }

    function _removeWire(bytes4 callSelector) internal {
        _revertIfCallSelectorIsHardcoded(callSelector);

        Dispatch storage dispatch = _dispatches[callSelector];

        address facet = dispatch.facet;

        require(dispatch.facet != address(0), CallSelectorNotWired(callSelector));

        EnumerableSet.Bytes32Set storage wiring = _wiring[facet];

        wiring.remove(_toWiring(callSelector, dispatch.delegateSelector));

        delete _dispatches[callSelector];

        if (wiring.length() == 0) {
            _facets.remove(facet);
        }

        emit WireRemoved(callSelector);
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

    function _revertIfCallSelectorIsHardcoded(bytes4 callSelector) internal pure {
        require(
            callSelector != IController.accessControls.selector &&
            callSelector != IController.beacon.selector &&
            callSelector != IController.proxy.selector &&
            callSelector != IController.rateLimits.selector,
            CallSelectorHardcoded(callSelector)
        );
    }

}
