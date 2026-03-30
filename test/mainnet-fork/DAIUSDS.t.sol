// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

}

abstract contract DaiUsds_TestBase is ForkTestBase {

    IERC20Like internal constant USDS = IERC20Like(Ethereum.USDS);

    address internal unauthorized = makeAddr("unauthorized");

}

contract MainnetController_DAIUSDS_SwapUSDSToDAI_Tests is DaiUsds_TestBase {

    function test_swapUSDSToDAI_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapUSDSToDAI(1_000_000e18);
    }

    function test_swapUSDSToDAI_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.swapUSDSToDAI(1_000_000e18);
    }

    function test_swapUSDSToDAI() external {
        vm.prank(RELAYER);
        mainnetController.mintUSDS(1_000_000e18);

        assertEq(USDS.balanceOf(almProxy), 1_000_000e18);
        assertEq(USDS.totalSupply(),       USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(almProxy), 0);
        assertEq(dai.totalSupply(),       DAI_SUPPLY);

        assertEq(USDS.allowance(almProxy, Ethereum.DAI_USDS), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.swapUSDSToDAI(1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(USDS.balanceOf(almProxy), 0);
        assertEq(USDS.totalSupply(),       USDS_SUPPLY);

        assertEq(dai.balanceOf(almProxy), 1_000_000e18);
        assertEq(dai.totalSupply(),       DAI_SUPPLY + 1_000_000e18);

        assertEq(USDS.allowance(almProxy, Ethereum.DAI_USDS), 0);
    }

}

contract MainnetController_DAIUSDS_SwapDAIToUSDS_Tests is DaiUsds_TestBase {

    function test_swapDAIToUSDS_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swapDAIToUSDS(1_000_000e18);
    }

    function test_swapDAIToUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.swapDAIToUSDS(1_000_000e18);
    }

    function test_swapDAIToUSDS() external {
        deal(address(dai), almProxy, 1_000_000e18);

        assertEq(USDS.balanceOf(almProxy), 0);
        assertEq(USDS.totalSupply(),       USDS_SUPPLY);

        assertEq(dai.balanceOf(almProxy), 1_000_000e18);
        assertEq(dai.totalSupply(),       DAI_SUPPLY);  // Supply not updated on deal

        assertEq(dai.allowance(almProxy, Ethereum.DAI_USDS), 0);

        vm.record();

        vm.prank(RELAYER);
        mainnetController.swapDAIToUSDS(1_000_000e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(USDS.balanceOf(almProxy), 1_000_000e18);
        assertEq(USDS.totalSupply(),       USDS_SUPPLY + 1_000_000e18);

        assertEq(dai.balanceOf(almProxy), 0);
        assertEq(dai.totalSupply(),       DAI_SUPPLY - 1_000_000e18);

        assertEq(dai.allowance(almProxy, Ethereum.DAI_USDS), 0);
    }

}
