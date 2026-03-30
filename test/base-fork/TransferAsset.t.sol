// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Base } from "../../lib/spark-address-registry/src/Base.sol";

import { makeAddressAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { MockTokenReturnFalse, MockTokenReturnNull } from "../mocks/Mocks.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

abstract contract TransferAsset_TestBase is ForkTestBase {

    IERC20Like internal constant USDC_BASE = IERC20Like(Base.USDC);

    address internal receiver     = makeAddr("receiver");
    address internal unauthorized = makeAddr("unauthorized");

    function setUp() public override {
        super.setUp();

        vm.startPrank(Base.SPARK_EXECUTOR);

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                foreignController.LIMIT_ASSET_TRANSFER(),
                Base.USDC,
                receiver
            ),
            1_000_000e6,
            uint256(1_000_000e6) / 1 days
        );

        vm.stopPrank();
    }

}

contract ForeignController_TransferAsset_Tests is TransferAsset_TestBase {

    function test_transferAsset_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.transferAsset(Base.USDC, receiver, 1_000_000e6);
    }

    function test_transferAsset_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        foreignController.transferAsset(Base.USDC, receiver, 1_000_000e6);
    }

    function test_transferAsset_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        foreignController.transferAsset(makeAddr("fake-token"), receiver, 1e18);
    }

    function test_transferAsset_rateLimitedBoundary() external {
        deal(Base.USDC, almProxy, 1_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.transferAsset(Base.USDC, receiver, 1_000_000e6 + 1);

        vm.prank(RELAYER);
        foreignController.transferAsset(Base.USDC, receiver, 1_000_000e6);
    }

    function test_transferAsset_transferFailedOnReturnFalse() external {
        MockTokenReturnFalse token = new MockTokenReturnFalse();

        vm.startPrank(Base.SPARK_EXECUTOR);

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                foreignController.LIMIT_ASSET_TRANSFER(),
                address(token),
                receiver
            ),
            1_000_000e18,
            uint256(1_000_000e18) / 1 days
        );

        vm.stopPrank();

        deal(address(token), almProxy, 1_000_000e18);

        vm.expectRevert("TransferAssetFacet/transfer-failed");
        vm.prank(RELAYER);
        foreignController.transferAsset(address(token), receiver, 1_000_000e18);
    }

    function test_transferAsset() external {
        deal(Base.USDC, almProxy, 1_000_000e6);

        assertEq(USDC_BASE.balanceOf(receiver), 0);
        assertEq(USDC_BASE.balanceOf(almProxy), 1_000_000e6);

        vm.record();

        vm.prank(RELAYER);
        foreignController.transferAsset(Base.USDC, receiver, 1_000_000e6);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(USDC_BASE.balanceOf(receiver), 1_000_000e6);
        assertEq(USDC_BASE.balanceOf(almProxy), 0);
    }

    function test_transferAsset_noReturnData() external {
        MockTokenReturnNull token = new MockTokenReturnNull("Token", "TKN", 6);

        vm.startPrank(Base.SPARK_EXECUTOR);

        rateLimits.setRateLimitData(
            makeAddressAddressKey(
                foreignController.LIMIT_ASSET_TRANSFER(),
                address(token),
                receiver
            ),
            1_000_000e6,
            uint256(1_000_000e6) / 1 days
        );

        vm.stopPrank();

        deal(address(token), almProxy, 1_000_000e6);

        assertEq(token.balanceOf(receiver), 0);
        assertEq(token.balanceOf(almProxy), 1_000_000e6);

        vm.prank(RELAYER);
        foreignController.transferAsset(address(token), receiver, 1_000_000e6);

        assertEq(token.balanceOf(receiver), 1_000_000e6);
        assertEq(token.balanceOf(almProxy), 0);
    }

}
