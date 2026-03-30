// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ALMProxyFreezable } from "../../../src/ALMProxyFreezable.sol";

import { MockTarget } from "../mocks/MockTarget.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

abstract contract Freezable_RemoveRelayer_TestBase is UnitTestBase {

    event ExampleEvent(
        address indexed exampleAddress,
        uint256 exampleValue,
        uint256 exampleReturn,
        address caller,
        uint256 value
    );

    event RelayerRemoved(address indexed relayer);

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

        vm.startPrank(admin);
        almProxyFreezable.grantRole(FREEZER_ROLE, freezer);
        almProxyFreezable.grantRole(RELAYER_ROLE, relayer);
        vm.stopPrank();

        target = address(new MockTarget());
    }

}

contract ALMProxy_Freezable_RemoveRelayer_Tests is Freezable_RemoveRelayer_TestBase {

    function test_removeRelayer_unauthorizedAccount() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            FREEZER_ROLE
        ));
        vm.prank(unauthorized);
        almProxyFreezable.removeRelayer(relayer);

        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            admin,
            FREEZER_ROLE
        ));
        vm.prank(admin);
        almProxyFreezable.removeRelayer(relayer);
    }

    function test_removeRelayer() external {
        // ALM Proxy Freezable is msg.sender, target emits the event
        vm.expectEmit(target);
        emit ExampleEvent(exampleAddress, 42, 84, address(almProxyFreezable), 0);

        vm.prank(relayer);
        bytes memory returnData = almProxyFreezable.doCall(target, data);

        assertEq(abi.decode(returnData, (uint256)), 84);

        // Before has relayer role
        assertTrue(almProxyFreezable.hasRole(RELAYER_ROLE, relayer));

        // Freezer comes in and removes relayer.
        vm.expectEmit(address(almProxyFreezable));
        emit RelayerRemoved(relayer);

        vm.prank(freezer);
        almProxyFreezable.removeRelayer(relayer);

        // After no longer has relayer role
        assertFalse(almProxyFreezable.hasRole(RELAYER_ROLE, relayer));

        // After can no longer call as relayer
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            relayer,
            RELAYER_ROLE
        ));
        vm.prank(relayer);
        almProxyFreezable.doCall(target, data);
    }

}
