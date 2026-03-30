// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ALMProxy }          from "../../../src/ALMProxy.sol";
import { ALMProxyFreezable } from "../../../src/ALMProxyFreezable.sol";

import { MockTarget } from "../mocks/MockTarget.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

abstract contract ALMProxy_Call_TestBase is UnitTestBase {

    event ExampleEvent(
        address indexed exampleAddress,
        uint256 exampleValue,
        uint256 exampleReturn,
        address caller,
        uint256 value
    );

    ALMProxy internal almProxy;

    address internal target;

    address internal controller     = makeAddr("controller");
    address internal exampleAddress = makeAddr("exampleAddress");
    address internal unauthorized   = makeAddr("unauthorized");

    bytes internal data = abi.encodeWithSignature(
        "exampleCall(address,uint256)",
        exampleAddress,
        42
    );

    function setUp() public virtual {
        almProxy = new ALMProxy(admin);

        vm.prank(admin);
        almProxy.grantRole(CONTROLLER_ROLE, controller);

        target = address(new MockTarget());
    }

}

contract ALMProxy_DoCall_Tests is ALMProxy_Call_TestBase {

    function test_doCall_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            CONTROLLER_ROLE
        ));
        vm.prank(unauthorized);
        almProxy.doCall(target, data);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            CONTROLLER_ROLE
        ));
        vm.prank(admin);
        almProxy.doCall(target, data);
    }

    function test_doCall() external {
        // ALM Proxy is msg.sender, target emits the event
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxy), 0);

        vm.prank(controller);
        bytes memory returnData = almProxy.doCall(target, data);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

}

contract ALMProxy_DoCallWithValue_Tests is ALMProxy_Call_TestBase {

    function test_doCallWithValue_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            CONTROLLER_ROLE
        ));
        vm.prank(unauthorized);
        almProxy.doCallWithValue(target, data, 1e18);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            CONTROLLER_ROLE
        ));
        vm.prank(admin);
        almProxy.doCallWithValue(target, data, 1e18);
    }

    function test_doCallWithValue_notEnoughBalanceBoundary() external {
        deal(address(almProxy), 1e18 - 1);

        vm.expectRevert(abi.encodeWithSignature(
            "AddressInsufficientBalance(address)",
            address(almProxy)
        ));
        vm.prank(controller);
        almProxy.doCallWithValue(target, data, 1e18);

        deal(address(almProxy), 1e18);

        vm.prank(controller);
        almProxy.doCallWithValue(target, data, 1e18);
    }

    function test_doCallWithValue() external {
        deal(address(almProxy), 1e18);

        // ALM Proxy is msg.sender, target emits the event
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxy), 1e18);

        vm.prank(controller);
        bytes memory returnData = almProxy.doCallWithValue(target, data, 1e18);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

    function test_doCallWithValue_msgValue() external {
        deal(controller, 1e18);

        // ALM Proxy is msg.sender, target emits the event, msg.value sent to proxy then target
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxy), 1e18);

        vm.prank(controller);
        bytes memory returnData = almProxy.doCallWithValue{value: 1e18}(target, data, 1e18);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

}

contract ALMProxy_DoDelegateCall_Tests is ALMProxy_Call_TestBase {

    function test_doDelegateCall_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            CONTROLLER_ROLE
        ));
        vm.prank(unauthorized);
        almProxy.doDelegateCall(target, data);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            CONTROLLER_ROLE
        ));
        vm.prank(admin);
        almProxy.doDelegateCall(target, data);
    }

    function test_doDelegateCall() external {
        // L1 Controller is msg.sender, almProxy emits the event
        vm.expectEmit(address(almProxy));
        emit ExampleEvent(exampleAddress, 42, 84, controller, 0);

        vm.prank(controller);
        bytes memory returnData = almProxy.doDelegateCall(target, data);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

}

abstract contract ALMProxyFreezable_Call_TestBase is UnitTestBase {

    event ExampleEvent(
        address indexed exampleAddress,
        uint256 exampleValue,
        uint256 exampleReturn,
        address caller,
        uint256 value
    );

    ALMProxyFreezable internal almProxyFreezable;

    address internal target;

    address internal exampleAddress = makeAddr("exampleAddress");
    address internal unauthorized   = makeAddr("unauthorized");

    bytes internal data = abi.encodeWithSignature(
        "exampleCall(address,uint256)",
        exampleAddress,
        42
    );

    function setUp() public virtual {
        almProxyFreezable = new ALMProxyFreezable(admin);

        vm.prank(admin);
        almProxyFreezable.grantRole(RELAYER_ROLE, relayer);

        target = address(new MockTarget());
    }

}

contract ALMProxyFreezable_DoCall_Tests is ALMProxyFreezable_Call_TestBase {

    function test_doCall_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        almProxyFreezable.doCall(target, data);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            RELAYER_ROLE
        ));
        vm.prank(admin);
        almProxyFreezable.doCall(target, data);
    }

    function test_doCall() external {
        // ALM Proxy is msg.sender, target emits the event
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxyFreezable), 0);

        vm.prank(relayer);
        bytes memory returnData = almProxyFreezable.doCall(target, data);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

}

contract ALMProxyFreezable_DoCallWithValue_Tests is ALMProxyFreezable_Call_TestBase {

    function test_doCallWithValue_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        almProxyFreezable.doCallWithValue(target, data, 1e18);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            RELAYER_ROLE
        ));
        vm.prank(admin);
        almProxyFreezable.doCallWithValue(target, data, 1e18);
    }

    function test_doCallWithValue_notEnoughBalanceBoundary() external {
        deal(address(almProxyFreezable), 1e18 - 1);

        vm.expectRevert(abi.encodeWithSignature(
            "AddressInsufficientBalance(address)",
            address(almProxyFreezable)
        ));
        vm.prank(relayer);
        almProxyFreezable.doCallWithValue(target, data, 1e18);

        deal(address(almProxyFreezable), 1e18);

        vm.prank(relayer);
        almProxyFreezable.doCallWithValue(target, data, 1e18);
    }

    function test_doCallWithValue() external {
        deal(address(almProxyFreezable), 1e18);

        // ALM Proxy is msg.sender, target emits the event
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxyFreezable), 1e18);

        vm.prank(relayer);
        bytes memory returnData = almProxyFreezable.doCallWithValue(target, data, 1e18);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

    function test_doCallWithValue_msgValue() external {
        deal(relayer, 1e18);

        // ALM Proxy is msg.sender, target emits the event, msg.value sent to proxy then target
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxyFreezable), 1e18);

        vm.prank(relayer);
        bytes memory returnData = almProxyFreezable.doCallWithValue{value: 1e18}(target, data, 1e18);

        assertEq(abi.decode(returnData, (uint256)), 84);
    }

}
