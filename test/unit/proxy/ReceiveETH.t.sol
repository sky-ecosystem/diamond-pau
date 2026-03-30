// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ALMProxy } from "../../../src/ALMProxy.sol";

import { UnitTestBase } from "../UnitTestBase.t.sol";

contract ALMProxy_ReceiveETH_Tests is UnitTestBase {

    function test_receiveETH() external {
        ALMProxy almProxy = new ALMProxy(admin);

        address account = makeAddr("account");

        deal(account, 10 ether);

        assertEq(account.balance,           10 ether);
        assertEq(address(almProxy).balance, 0);

        vm.prank(account);
        payable(address(almProxy)).transfer(10 ether);

        assertEq(account.balance,           0);
        assertEq(address(almProxy).balance, 10 ether);
    }

}
