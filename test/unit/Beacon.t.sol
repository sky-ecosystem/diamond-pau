// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { IAccessControl } from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { EnumerableSet }   from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { IBeacon }     from "../../src/interfaces/IBeacon.sol";
import { IController } from "../../src/interfaces/IController.sol";

import { Beacon } from "../../src/Beacon.sol";

interface IMockFacet {

    error MockError(uint256 arg);

    function foo() external;

    function bar(
        address           arg0,
        bool[]     memory arg1,
        bytes32           arg2,
        int256[][] memory arg3,
        uint256           arg4,
        bytes      memory arg5,
        string[]   memory arg6
    )
        external
        returns (
            string[]   memory,
            bytes      memory,
            uint256,
            int256[][] memory,
            bytes32,
            bool[]     memory,
            address
        );

}

interface IMockController {

    function facetFoo() external;

    function facetBar(
        address           arg0,
        bool[]     memory arg1,
        bytes32           arg2,
        int256[][] memory arg3,
        uint256           arg4,
        bytes      memory arg5,
        string[]   memory arg6
    )
        external
        returns (
            string[]   memory,
            bytes      memory,
            uint256,
            int256[][] memory,
            bytes32,
            bool[]     memory,
            address
        );

}

contract BeaconHarness is Beacon {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    constructor(address admin) Beacon(admin) {}

    function __addFacet(address facet) external {
        _facets.add(facet);
    }

    function __removeFacet(address facet) external {
        _facets.remove(facet);
    }

    function __setDispatch(bytes4 callSelector, address facet, bytes4 delegateSelector) external {
        _dispatches[callSelector] = Dispatch(facet, delegateSelector);
    }

    function __addWire(address facet, bytes4 callSelector, bytes4 delegateSelector) external {
        _wiring[facet].add(_toWiring(callSelector, delegateSelector));
    }

    function __removeWire(address facet, bytes4 callSelector, bytes4 delegateSelector) external {
        _wiring[facet].remove(_toWiring(callSelector, delegateSelector));
    }

    function __getHasFacet(address facet) external view returns (bool) {
        return _facets.contains(facet);
    }

    function __getDispatchFacet(bytes4 callSelector) external view returns (address) {
        return _dispatches[callSelector].facet;
    }

    function __getDispatchSelector(bytes4 callSelector) external view returns (bytes4) {
        return _dispatches[callSelector].delegateSelector;
    }

    function __getHasWiring(address facet, bytes4 callSelector, bytes4 delegateSelector) external view returns (bool) {
        return _wiring[facet].contains(_toWiring(callSelector, delegateSelector));
    }

}

contract Beacon_Tests is Test {

    bytes32 internal constant _REENTRANCY_GUARD_SLOT        = bytes32(uint256(0));
    bytes32 internal constant _REENTRANCY_GUARD_NOT_ENTERED = bytes32(uint256(1));
    bytes32 internal constant _REENTRANCY_GUARD_ENTERED     = bytes32(uint256(2));

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    address internal admin        = makeAddr("admin");
    address internal unauthorized = makeAddr("unauthorized");

    BeaconHarness internal beacon;

    function setUp() external {
        beacon = new BeaconHarness(admin);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_zeroAdmin() external {
        vm.expectRevert(IBeacon.ZeroAdmin.selector);
        new BeaconHarness(address(0));
    }

    function test_constructor() external {
        assertEq(beacon.hasRole(DEFAULT_ADMIN_ROLE, admin),     true);
        assertEq(beacon.getRoleMember(DEFAULT_ADMIN_ROLE, 0),   admin);
        assertEq(beacon.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
    }

    /**********************************************************************************************/
    /*** addWire Tests                                                                          ***/
    /**********************************************************************************************/

    function test_addWire_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.addWire(address(0), IBeacon.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.addWire(address(0), IBeacon.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire_zeroFacet() external {
        vm.expectRevert(IBeacon.ZeroFacet.selector);
        vm.prank(admin);
        beacon.addWire(address(0), IBeacon.Wire(bytes4(0), bytes4(0)));
    }

    function test_addWire_callSelectorHardcoded() external {
        address facet = makeAddr("facet");

        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.accessControls.selector
            )
        );

        vm.prank(admin);
        beacon.addWire(facet, IBeacon.Wire(IController.accessControls.selector, bytes4(0)));
    }

    function test_addWire_callSelectorHardcoded_exhaustive() external {
        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](4);
        callSelectors[0]  = IController.accessControls.selector;
        callSelectors[1]  = IController.beacon.selector;
        callSelectors[2]  = IController.proxy.selector;
        callSelectors[3]  = IController.rateLimits.selector;

        for (uint256 i = 0; i < callSelectors.length; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IBeacon.CallSelectorHardcoded.selector,
                    callSelectors[i]
                )
            );

            vm.prank(admin);
            beacon.addWire(facet, IBeacon.Wire(callSelectors[i], bytes4(0)));
        }
    }

    function test_addWire_callSelectorAlreadyWired() external {
        address facet        = makeAddr("facet");
        bytes4  callSelector = 0x12345678;

        beacon.__setDispatch(callSelector, facet, bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorAlreadyWired.selector, callSelector));
        vm.prank(admin);
        beacon.addWire(facet, IBeacon.Wire(callSelector, bytes4(0)));
    }

    function test_addWire() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(callSelector),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelector), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, callSelector, delegateSelector), false);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireAdded(callSelector, delegateSelector, facet);

        vm.prank(admin);
        beacon.addWire(facet, IBeacon.Wire(callSelector, delegateSelector));

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(callSelector),    facet);
        assertEq(beacon.__getDispatchSelector(callSelector), delegateSelector);

        assertEq(beacon.__getHasWiring(facet, callSelector, delegateSelector), true);
    }

    /**********************************************************************************************/
    /*** addWires Tests                                                                         ***/
    /**********************************************************************************************/

    function test_addWires_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.addWires(address(0), new IBeacon.Wire[](0));
    }

    function test_addWires_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.addWires(address(0), new IBeacon.Wire[](0));
    }

    function test_addWires_emptyArray() external {
        vm.expectRevert(IBeacon.EmptyArray.selector);
        vm.prank(admin);
        beacon.addWires(address(0), new IBeacon.Wire[](0));
    }

    function test_addWires_zeroFacet() external {
        IBeacon.Wire[] memory wires = new IBeacon.Wire[](2);

        vm.expectRevert(IBeacon.ZeroFacet.selector);
        vm.prank(admin);
        beacon.addWires(address(0), wires);
    }

    function test_addWires_callSelectorHardcoded() external {
        address facet = makeAddr("facet");

        IBeacon.Wire[] memory wires = new IBeacon.Wire[](2);
        wires[0] = IBeacon.Wire(IController.accessControls.selector, bytes4(0));
        wires[1] = IBeacon.Wire(0x12456789,                          bytes4(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.accessControls.selector
            )
        );

        vm.prank(admin);
        beacon.addWires(facet, wires);

        wires[0] = IBeacon.Wire(0x12345678,                  bytes4(0));
        wires[1] = IBeacon.Wire(IController.beacon.selector, bytes4(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.beacon.selector
            )
        );

        vm.prank(admin);
        beacon.addWires(facet, wires);
    }

    function test_addWires_callSelectorAlreadyWired() external {
        address facet        = makeAddr("facet");
        bytes4  callSelector = 0x12345678;

        beacon.__setDispatch(callSelector, facet, bytes4(0));

        IBeacon.Wire[] memory wires = new IBeacon.Wire[](2);
        wires[0] = IBeacon.Wire(callSelector, bytes4(0));
        wires[1] = IBeacon.Wire(0x87654321,   bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorAlreadyWired.selector, callSelector));
        vm.prank(admin);
        beacon.addWires(facet, wires);

        wires[0] = IBeacon.Wire(0x87654321,   bytes4(0));
        wires[1] = IBeacon.Wire(callSelector, bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorAlreadyWired.selector, callSelector));
        vm.prank(admin);
        beacon.addWires(facet, wires);
    }

    function test_addWires() external {
        address facet = makeAddr("facet");

        IBeacon.Wire[] memory wires = new IBeacon.Wire[](2);
        wires[0] = IBeacon.Wire(0x12345678, 0x87654321);
        wires[1] = IBeacon.Wire(0xFEDCBA98, 0x89ABCDEF);

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(wires[0].callSelector),    address(0));
        assertEq(beacon.__getDispatchSelector(wires[0].callSelector), bytes4(0));

        assertEq(beacon.__getDispatchFacet(wires[1].callSelector),    address(0));
        assertEq(beacon.__getDispatchSelector(wires[1].callSelector), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, wires[0].callSelector, wires[0].delegateSelector), false);
        assertEq(beacon.__getHasWiring(facet, wires[1].callSelector, wires[1].delegateSelector), false);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireAdded(0x12345678, 0x87654321, makeAddr("facet"));

        vm.expectEmit(address(beacon));
        emit IBeacon.WireAdded(0xFEDCBA98, 0x89ABCDEF, makeAddr("facet"));

        vm.prank(admin);
        beacon.addWires(facet, wires);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(wires[0].callSelector),    facet);
        assertEq(beacon.__getDispatchSelector(wires[0].callSelector), wires[0].delegateSelector);

        assertEq(beacon.__getDispatchFacet(wires[1].callSelector),    facet);
        assertEq(beacon.__getDispatchSelector(wires[1].callSelector), wires[1].delegateSelector);

        assertEq(beacon.__getHasWiring(facet, wires[0].callSelector, wires[0].delegateSelector), true);
        assertEq(beacon.__getHasWiring(facet, wires[1].callSelector, wires[1].delegateSelector), true);
    }

    /**********************************************************************************************/
    /*** removeWire Tests                                                                       ***/
    /**********************************************************************************************/

    function test_removeWire_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.removeWire(bytes4(0));
    }

    function test_removeWire_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeWire(bytes4(0));
    }

    function test_removeWire_callSelectorIsHardcoded() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.accessControls.selector
            )
        );

        vm.prank(admin);
        beacon.removeWire(IController.accessControls.selector);
    }

    function test_removeWire_callSelectorNotWired() external {
        bytes4 callSelector = 0x12456789;

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorNotWired.selector, callSelector));
        vm.prank(admin);
        beacon.removeWire(callSelector);
    }

    function test_removeWire() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        beacon.__addFacet(facet);

        beacon.__setDispatch(callSelector, facet, delegateSelector);

        beacon.__addWire(facet, callSelector, delegateSelector);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(callSelector),    facet);
        assertEq(beacon.__getDispatchSelector(callSelector), delegateSelector);

        assertEq(beacon.__getHasWiring(facet, callSelector, delegateSelector), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelector);

        vm.prank(admin);
        beacon.removeWire(callSelector);

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(callSelector),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelector), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, callSelector, delegateSelector), false);
    }

    function test_removeWire_oneThenLast() external {
        address facet = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;

        bytes4[] memory delegateSelectors = new bytes4[](2);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;

        beacon.__addFacet(facet);

        beacon.__setDispatch(callSelectors[0], facet, delegateSelectors[0]);
        beacon.__setDispatch(callSelectors[1], facet, delegateSelectors[1]);

        beacon.__addWire(facet, callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facet, callSelectors[1], delegateSelectors[1]);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), delegateSelectors[0]);
        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), delegateSelectors[1]);

        assertEq(beacon.__getHasWiring(facet, callSelectors[0], delegateSelectors[0]), true);
        assertEq(beacon.__getHasWiring(facet, callSelectors[1], delegateSelectors[1]), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[0]);

        vm.prank(admin);
        beacon.removeWire(callSelectors[0]);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), bytes4(0));
        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), delegateSelectors[1]);

        assertEq(beacon.__getHasWiring(facet, callSelectors[0], delegateSelectors[0]), false);
        assertEq(beacon.__getHasWiring(facet, callSelectors[1], delegateSelectors[1]), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[1]);

        vm.prank(admin);
        beacon.removeWire(callSelectors[1]);

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), bytes4(0));
        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, callSelectors[0], delegateSelectors[0]), false);
        assertEq(beacon.__getHasWiring(facet, callSelectors[1], delegateSelectors[1]), false);
    }

    /**********************************************************************************************/
    /*** removeWires Tests                                                                      ***/
    /**********************************************************************************************/

    function test_removeWires_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.removeWires(new bytes4[](0));
    }

    function test_removeWires_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeWires(new bytes4[](0));
    }

    function test_removeWires_emptyArray() external {
        vm.expectRevert(IBeacon.EmptyArray.selector);
        vm.prank(admin);
        beacon.removeWires(new bytes4[](0));
    }

    function test_removeWires_callSelectorHardcoded() external {
        beacon.__setDispatch(0x12456789, makeAddr("facet"), bytes4(0));

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = IController.accessControls.selector;
        callSelectors[1] = 0x12456789;

        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.accessControls.selector
            )
        );

        vm.prank(admin);
        beacon.removeWires(callSelectors);

        callSelectors[0] = 0x12456789;
        callSelectors[1] = IController.beacon.selector;

        vm.expectRevert(
            abi.encodeWithSelector(
                IBeacon.CallSelectorHardcoded.selector,
                IController.beacon.selector
            )
        );

        vm.prank(admin);
        beacon.removeWires(callSelectors);
    }

    function test_removeWires_callSelectorNotWired() external {
        bytes4 callSelector = 0x12345678;

        beacon.__setDispatch(0x87654321, makeAddr("facet"), bytes4(0));

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = callSelector;
        callSelectors[1] = 0x87654321;

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorNotWired.selector, callSelector));
        vm.prank(admin);
        beacon.removeWires(callSelectors);

        callSelectors[0] = 0x87654321;
        callSelectors[1] = callSelector;

        vm.expectRevert(abi.encodeWithSelector(IBeacon.CallSelectorNotWired.selector, callSelector));
        vm.prank(admin);
        beacon.removeWires(callSelectors);
    }

    function test_removeWires() external {
        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;

        address[] memory facets = new address[](2);
        facets[0] = makeAddr("facet1");
        facets[1] = makeAddr("facet2");

        bytes4[] memory delegateSelectors = new bytes4[](2);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;

        beacon.__addFacet(facets[0]);
        beacon.__addFacet(facets[1]);

        beacon.__setDispatch(callSelectors[0], facets[0], delegateSelectors[0]);
        beacon.__setDispatch(callSelectors[1], facets[1], delegateSelectors[1]);

        beacon.__addWire(facets[0], callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facets[1], callSelectors[1], delegateSelectors[1]);

        assertEq(beacon.__getHasFacet(facets[0]), true);
        assertEq(beacon.__getHasFacet(facets[1]), true);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    facets[0]);
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), delegateSelectors[0]);

        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    facets[1]);
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), delegateSelectors[1]);

        assertEq(beacon.__getHasWiring(facets[0], callSelectors[0], delegateSelectors[0]), true);
        assertEq(beacon.__getHasWiring(facets[1], callSelectors[1], delegateSelectors[1]), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[0]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[1]);

        vm.prank(admin);
        beacon.removeWires(callSelectors);

        assertEq(beacon.__getHasFacet(facets[0]), false);
        assertEq(beacon.__getHasFacet(facets[1]), false);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), bytes4(0));

        assertEq(beacon.__getHasWiring(facets[0], callSelectors[0], delegateSelectors[0]), false);
        assertEq(beacon.__getHasWiring(facets[1], callSelectors[1], delegateSelectors[1]), false);
    }

    function test_removeWires_halfThenHalf() external {
        address facet = makeAddr("facet");

        bytes4[] memory firstHalfCallSelectors = new bytes4[](2);
        firstHalfCallSelectors[0] = 0x12345678;
        firstHalfCallSelectors[1] = 0x89ABCDEF;

        bytes4[] memory secondHalfCallSelectors = new bytes4[](2);
        secondHalfCallSelectors[0] = 0x11111111;
        secondHalfCallSelectors[1] = 0x22222222;

        bytes4[] memory firstHalfDelegateSelectors = new bytes4[](2);
        firstHalfDelegateSelectors[0] = 0x87654321;
        firstHalfDelegateSelectors[1] = 0xFECDAB98;

        bytes4[] memory secondHalfDelegateSelectors = new bytes4[](2);
        secondHalfDelegateSelectors[0] = 0x33333333;
        secondHalfDelegateSelectors[1] = 0x44444444;

        beacon.__addFacet(facet);

        beacon.__setDispatch(firstHalfCallSelectors[0],  facet, firstHalfDelegateSelectors[0]);
        beacon.__setDispatch(firstHalfCallSelectors[1],  facet, firstHalfDelegateSelectors[1]);
        beacon.__setDispatch(secondHalfCallSelectors[0], facet, secondHalfDelegateSelectors[0]);
        beacon.__setDispatch(secondHalfCallSelectors[1], facet, secondHalfDelegateSelectors[1]);

        beacon.__addWire(facet, firstHalfCallSelectors[0],  firstHalfDelegateSelectors[0]);
        beacon.__addWire(facet, firstHalfCallSelectors[1],  firstHalfDelegateSelectors[1]);
        beacon.__addWire(facet, secondHalfCallSelectors[0], secondHalfDelegateSelectors[0]);
        beacon.__addWire(facet, secondHalfCallSelectors[1], secondHalfDelegateSelectors[1]);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[0]),    facet);
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[0]), firstHalfDelegateSelectors[0]);

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[1]), firstHalfDelegateSelectors[1]);

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[0]),    facet);
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[0]), secondHalfDelegateSelectors[0]);

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[1]), secondHalfDelegateSelectors[1]);

        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[0],  firstHalfDelegateSelectors[0]),  true);
        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[1],  firstHalfDelegateSelectors[1]),  true);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[0], secondHalfDelegateSelectors[0]), true);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[1], secondHalfDelegateSelectors[1]), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(firstHalfCallSelectors[0]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(firstHalfCallSelectors[1]);

        vm.prank(admin);
        beacon.removeWires(firstHalfCallSelectors);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[0]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[1]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[0]),    facet);
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[0]), secondHalfDelegateSelectors[0]);

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[1]), secondHalfDelegateSelectors[1]);

        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[0],  firstHalfDelegateSelectors[0]),  false);
        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[1],  firstHalfDelegateSelectors[1]),  false);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[0], secondHalfDelegateSelectors[0]), true);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[1], secondHalfDelegateSelectors[1]), true);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(secondHalfCallSelectors[0]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(secondHalfCallSelectors[1]);

        vm.prank(admin);
        beacon.removeWires(secondHalfCallSelectors);

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[0]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(firstHalfCallSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(firstHalfCallSelectors[1]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[0]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(secondHalfCallSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(secondHalfCallSelectors[1]), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[0],  firstHalfDelegateSelectors[0]),  false);
        assertEq(beacon.__getHasWiring(facet, firstHalfCallSelectors[1],  firstHalfDelegateSelectors[1]),  false);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[0], secondHalfDelegateSelectors[0]), false);
        assertEq(beacon.__getHasWiring(facet, secondHalfCallSelectors[1], secondHalfDelegateSelectors[1]), false);
    }

    /**********************************************************************************************/
    /*** removeAllWiresFor Tests                                                                ***/
    /**********************************************************************************************/

    function test_removeAllWiresFor_reentrancy() external {
        vm.store(address(beacon), _REENTRANCY_GUARD_SLOT, _REENTRANCY_GUARD_ENTERED);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        beacon.removeAllWiresFor(address(0));
    }

    function test_removeAllWiresFor_notAdmin() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                DEFAULT_ADMIN_ROLE
            )
        );

        vm.prank(unauthorized);
        beacon.removeAllWiresFor(address(0));
    }

    function test_removeAllWiresFor_emptyArray() external {
        vm.expectRevert(IBeacon.EmptyArray.selector);
        vm.prank(admin);
        beacon.removeAllWiresFor(address(0));
    }

    function test_removeAllWiresFor() external {
        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](4);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;
        callSelectors[3] = 0x22222222;

        bytes4[] memory delegateSelectors = new bytes4[](4);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;
        delegateSelectors[3] = 0x44444444;

        beacon.__addFacet(facet);

        beacon.__setDispatch(callSelectors[0], facet, delegateSelectors[0]);
        beacon.__setDispatch(callSelectors[1], facet, delegateSelectors[1]);
        beacon.__setDispatch(callSelectors[2], facet, delegateSelectors[2]);
        beacon.__setDispatch(callSelectors[3], facet, delegateSelectors[3]);

        beacon.__addWire(facet, callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facet, callSelectors[1], delegateSelectors[1]);
        beacon.__addWire(facet, callSelectors[2], delegateSelectors[2]);
        beacon.__addWire(facet, callSelectors[3], delegateSelectors[3]);

        assertEq(beacon.__getHasFacet(facet), true);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), delegateSelectors[0]);

        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), delegateSelectors[1]);

        assertEq(beacon.__getDispatchFacet(callSelectors[2]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[2]), delegateSelectors[2]);

        assertEq(beacon.__getDispatchFacet(callSelectors[3]),    facet);
        assertEq(beacon.__getDispatchSelector(callSelectors[3]), delegateSelectors[3]);

        assertEq(beacon.__getHasWiring(facet, callSelectors[0], delegateSelectors[0]), true);
        assertEq(beacon.__getHasWiring(facet, callSelectors[1], delegateSelectors[1]), true);
        assertEq(beacon.__getHasWiring(facet, callSelectors[2], delegateSelectors[2]), true);
        assertEq(beacon.__getHasWiring(facet, callSelectors[3], delegateSelectors[3]), true);

        // NOTE: Ordering is 0 then reverse order of 1, 2, 3 due to how EnumerableSet inserts work.

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[0]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[3]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[2]);

        vm.expectEmit(address(beacon));
        emit IBeacon.WireRemoved(callSelectors[1]);

        vm.prank(admin);
        beacon.removeAllWiresFor(facet);

        assertEq(beacon.__getHasFacet(facet), false);

        assertEq(beacon.__getDispatchFacet(callSelectors[0]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[0]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(callSelectors[1]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[1]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(callSelectors[2]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[2]), bytes4(0));

        assertEq(beacon.__getDispatchFacet(callSelectors[3]),    address(0));
        assertEq(beacon.__getDispatchSelector(callSelectors[3]), bytes4(0));

        assertEq(beacon.__getHasWiring(facet, callSelectors[0], delegateSelectors[0]), false);
        assertEq(beacon.__getHasWiring(facet, callSelectors[1], delegateSelectors[1]), false);
        assertEq(beacon.__getHasWiring(facet, callSelectors[2], delegateSelectors[2]), false);
        assertEq(beacon.__getHasWiring(facet, callSelectors[3], delegateSelectors[3]), false);
    }

    /**********************************************************************************************/
    /*** circuits Tests                                                                         ***/
    /**********************************************************************************************/

    function test_circuits() external {
        address[] memory facets = new address[](2);
        facets[0] = makeAddr("facet1");
        facets[1] = makeAddr("facet2");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        beacon.__addFacet(facets[0]);
        beacon.__addFacet(facets[1]);

        beacon.__setDispatch(callSelectors[0], facets[0], delegateSelectors[0]);
        beacon.__setDispatch(callSelectors[1], facets[1], delegateSelectors[1]);
        beacon.__setDispatch(callSelectors[2], facets[1], delegateSelectors[2]);

        beacon.__addWire(facets[0], callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facets[1], callSelectors[1], delegateSelectors[1]);
        beacon.__addWire(facets[1], callSelectors[2], delegateSelectors[2]);

        IBeacon.Circuit[] memory circuits = beacon.circuits();

        assertEq(circuits.length, 2);

        assertEq(circuits[0].facet, facets[0]);

        assertEq(circuits[0].wires.length, 1);

        assertEq(circuits[0].wires[0].callSelector,     callSelectors[0]);
        assertEq(circuits[0].wires[0].delegateSelector, delegateSelectors[0]);

        assertEq(circuits[1].facet, facets[1]);

        assertEq(circuits[1].wires.length, 2);

        assertEq(circuits[1].wires[0].callSelector,     callSelectors[1]);
        assertEq(circuits[1].wires[0].delegateSelector, delegateSelectors[1]);
        assertEq(circuits[1].wires[1].callSelector,     callSelectors[2]);
        assertEq(circuits[1].wires[1].delegateSelector, delegateSelectors[2]);

    }

    /**********************************************************************************************/
    /*** getDispatch Tests                                                                      ***/
    /**********************************************************************************************/

    function test_getDispatch() external {
        bytes4  callSelector     = 0x12345678;
        address facet            = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        bytes4  delegateSelector = 0x87654321;

        beacon.__setDispatch(callSelector, facet, delegateSelector);

        IBeacon.Dispatch memory returnedDispatch = beacon.getDispatch(callSelector);

        assertEq(returnedDispatch.facet,            facet);
        assertEq(returnedDispatch.delegateSelector, delegateSelector);
    }

    /**********************************************************************************************/
    /*** getDispatches Tests                                                                    ***/
    /**********************************************************************************************/

    function test_getDispatches() external {
        address[] memory facets = new address[](2);
        facets[0] = makeAddr("facet1");
        facets[1] = makeAddr("facet2");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        beacon.__setDispatch(callSelectors[0], facets[0], delegateSelectors[0]);
        beacon.__setDispatch(callSelectors[1], facets[1], delegateSelectors[1]);
        beacon.__setDispatch(callSelectors[2], facets[1], delegateSelectors[2]);

        IBeacon.Dispatch[] memory dispatches = beacon.getDispatches(callSelectors);

        assertEq(dispatches.length, 3);

        assertEq(dispatches[0].facet,            facets[0]);
        assertEq(dispatches[0].delegateSelector, delegateSelectors[0]);
        assertEq(dispatches[1].facet,            facets[1]);
        assertEq(dispatches[1].delegateSelector, delegateSelectors[1]);
        assertEq(dispatches[2].facet,            facets[1]);
        assertEq(dispatches[2].delegateSelector, delegateSelectors[2]);
    }

    /**********************************************************************************************/
    /*** getWiring Tests                                                                        ***/
    /**********************************************************************************************/

    function test_getWiring() external {
        address facet = makeAddr("facet");

        bytes4[] memory callSelectors = new bytes4[](2);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;

        bytes4[] memory delegateSelectors = new bytes4[](2);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;

        beacon.__addWire(facet, callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facet, callSelectors[1], delegateSelectors[1]);

        IBeacon.Wire[] memory wiring = beacon.getWiring(facet);

        assertEq(wiring.length, 2);
        assertEq(wiring[0].callSelector,     callSelectors[0]);
        assertEq(wiring[0].delegateSelector, delegateSelectors[0]);
        assertEq(wiring[1].callSelector,     callSelectors[1]);
        assertEq(wiring[1].delegateSelector, delegateSelectors[1]);
    }

    /**********************************************************************************************/
    /*** getWirings Tests                                                                       ***/
    /**********************************************************************************************/

    function test_getWirings() external {
        address[] memory facets = new address[](2);
        facets[0] = makeAddr("facet1");
        facets[1] = makeAddr("facet2");

        bytes4[] memory callSelectors = new bytes4[](3);
        callSelectors[0] = 0x12345678;
        callSelectors[1] = 0x89ABCDEF;
        callSelectors[2] = 0x11111111;

        bytes4[] memory delegateSelectors = new bytes4[](3);
        delegateSelectors[0] = 0x87654321;
        delegateSelectors[1] = 0xFECDAB98;
        delegateSelectors[2] = 0x33333333;

        beacon.__addWire(facets[0], callSelectors[0], delegateSelectors[0]);
        beacon.__addWire(facets[1], callSelectors[1], delegateSelectors[1]);
        beacon.__addWire(facets[1], callSelectors[2], delegateSelectors[2]);

        IBeacon.Wire[][] memory wirings = beacon.getWirings(facets);

        assertEq(wirings.length, 2);

        assertEq(wirings[0].length, 1);

        assertEq(wirings[0][0].callSelector,     callSelectors[0]);
        assertEq(wirings[0][0].delegateSelector, delegateSelectors[0]);

        assertEq(wirings[1].length, 2);

        assertEq(wirings[1][0].callSelector,     callSelectors[1]);
        assertEq(wirings[1][0].delegateSelector, delegateSelectors[1]);
        assertEq(wirings[1][1].callSelector,     callSelectors[2]);
        assertEq(wirings[1][1].delegateSelector, delegateSelectors[2]);
    }

}
