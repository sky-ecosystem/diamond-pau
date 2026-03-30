// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

contract MainnetController_WrapAllProxyETH_Tests is ForkTestBase {

    IERC20Like internal constant WETH = IERC20Like(Ethereum.WETH);

    address internal unauthorized = makeAddr("unauthorized");

    function test_wrapAllProxyETH_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.wrapAllProxyETH();
    }

    function test_wrapAllProxyETH_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.wrapAllProxyETH();
    }

    function test_wrapAllProxyETH_zeroBalance() external {
        assertEq(almProxy.balance,         0);
        assertEq(WETH.balanceOf(almProxy), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.wrapAllProxyETH();

        _assertReentrancyGuardWrittenToTwice();

        assertEq(almProxy.balance,         0);
        assertEq(WETH.balanceOf(almProxy), 0);
    }

    function test_wrapAllProxyETH() external {
        deal(almProxy, 1 ether);

        assertEq(almProxy.balance,         1 ether);
        assertEq(WETH.balanceOf(almProxy), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.wrapAllProxyETH();

        _assertReentrancyGuardWrittenToTwice();

        assertEq(almProxy.balance,         0);
        assertEq(WETH.balanceOf(almProxy), 1 ether);
    }

}
