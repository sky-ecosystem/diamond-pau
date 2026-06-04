// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { NFATFacility } from "../../lib/nfat/src/NFATFacility.sol";

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { INFATPrimeFacet } from "../../src/facets/nfat-prime/INFATPrimeFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

abstract contract NFATPrime_TestBase is ForkTestBase {

    NFATFacility internal nfatFacility;
    address      internal nfatRecipient;

    bytes32 internal subscribeKey;
    bytes32 internal withdrawKey;
    bytes32 internal collectKey;

    uint256 internal constant SUBSCRIBE_AMOUNT = 1_000_000e18;

    function setUp() public virtual override {
        super.setUp();

        nfatRecipient = makeAddr("nfatRecipient");

        nfatFacility = new NFATFacility(Ethereum.USDS, "Test NFAT", "TNFAT");
        nfatFacility.file("recipient", nfatRecipient);
        nfatFacility.kiss(address(this));  // Make test contract an operator (bud)

        subscribeKey = mainnetController.nfatPrime_getSubscribeRateLimitKey(address(nfatFacility), Ethereum.USDS);
        withdrawKey  = mainnetController.nfatPrime_getWithdrawRateLimitKey(address(nfatFacility));
        collectKey   = mainnetController.nfatPrime_getCollectRateLimitKey(address(nfatFacility));

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setUnlimitedRateLimitData(subscribeKey);
        rateLimits.setUnlimitedRateLimitData(withdrawKey);
        rateLimits.setUnlimitedRateLimitData(collectKey);
        vm.stopPrank();

        // Deal more than the rate-limit max so the rate-limit boundary tests can exercise the
        // post-call decrement at exactly the limit + 1 without running out of gem first.
        deal(Ethereum.USDS, address(almProxy), 10_000_000e18);
    }

}

contract MainnetController_NFATPrime_Subscribe_Tests is NFATPrime_TestBase {

    function test_subscribe_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribe_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribe_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), 0, "");
    }

    function test_subscribe_zeroMaxAmount() external {
        // Rate limit is consumed by the actual ALMProxy balance delta post-call, so the
        // zero-maxAmount revert surfaces only after the facility call completes. Zero out the
        // configured limit and exercise that path.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribe_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 1_000_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), 1_000_000e18 + 1, "");

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), 1_000_000e18, "");
    }

    function test_subscribe() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 5_000_000e18, 0);

        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 0);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit INFATPrimeFacet.NFATPrimeSubscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18 - SUBSCRIBE_AMOUNT);
    }

    function test_subscribe_withData() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 5_000_000e18, 0);

        bytes memory data = abi.encode("agreement-id-123");

        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 0);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit INFATPrimeFacet.NFATPrimeSubscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, data);

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, data);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18 - SUBSCRIBE_AMOUNT);
    }

}

contract MainnetController_NFATPrime_Withdraw_Tests is NFATPrime_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_withdraw_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdraw_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdraw_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), 0);
    }

    function test_withdraw_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(withdrawKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdraw_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(withdrawKey, 500_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), 500_000e18 + 1);

        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), 500_000e18);
    }

    function test_withdraw() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(withdrawKey, 5_000_000e18, 0);

        assertEq(usds.balanceOf(address(almProxy)),            10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(nfatFacility.deposits(address(almProxy)),     SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey),  5_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit INFATPrimeFacet.NFATPrimeWithdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);

        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),            10_000_000e18);
        assertEq(nfatFacility.deposits(address(almProxy)),     0);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey),  5_000_000e18 - SUBSCRIBE_AMOUNT);
    }

}

contract MainnetController_NFATPrime_Collect_Tests is NFATPrime_TestBase {

    uint256 internal constant TOKEN_ID     = 1;
    uint256 internal constant REPAY_AMOUNT = 2_000_000e18;

    function setUp() public override {
        super.setUp();

        // Subscribe and issue so the proxy holds an NFT
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");

        nfatFacility.issue(address(almProxy), TOKEN_ID, SUBSCRIBE_AMOUNT);

        assertEq(nfatFacility.balanceOf(address(almProxy)), 1);

        assertEq(nfatFacility.ownerOf(TOKEN_ID), address(almProxy));

        // Fund the collectable balance via an external repayer
        deal(Ethereum.USDS, address(this), REPAY_AMOUNT);
        usds.approve(address(nfatFacility), REPAY_AMOUNT);
        nfatFacility.repay(TOKEN_ID, REPAY_AMOUNT);
    }

    function test_collect_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collect_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collect_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_collect_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(collectKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collect_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(collectKey, 1_000_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18 + 1);

        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collect() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(collectKey, 2_000_000e18, 0);

        uint256 collectAmount = 1_000_000e18;

        assertEq(usds.balanceOf(address(almProxy)),             10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(nfatFacility.collectable(TOKEN_ID),            REPAY_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(collectKey),    2_000_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit INFATPrimeFacet.NFATPrimeCollect(address(nfatFacility), TOKEN_ID, collectAmount);

        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, collectAmount);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),             10_000_000e18 - SUBSCRIBE_AMOUNT + collectAmount);
        assertEq(nfatFacility.collectable(TOKEN_ID),            REPAY_AMOUNT - collectAmount);
        assertEq(rateLimits.getCurrentRateLimit(collectKey),    2_000_000e18 - collectAmount);
    }

}
