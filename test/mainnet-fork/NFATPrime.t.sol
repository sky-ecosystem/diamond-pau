// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { NFATFacility } from "../../lib/nfat/src/NFATFacility.sol";

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

        subscribeKey =
            mainnetController.nfatPrime_getSubscribeRateLimitKey(address(nfatFacility), Ethereum.USDS);
        withdrawKey  =
            mainnetController.nfatPrime_getWithdrawRateLimitKey(address(nfatFacility), Ethereum.USDS);
        collectKey   =
            mainnetController.nfatPrime_getCollectRateLimitKey(address(nfatFacility), Ethereum.USDS);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(withdrawKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(collectKey,   1_000_000e18, uint256(1_000_000e18) / 4 hours);
        vm.stopPrank();

        // Deal more than the rate-limit max so the rate-limit boundary tests can exercise the
        // post-call decrement at exactly the limit + 1 without running out of gem first.
        deal(Ethereum.USDS, address(almProxy), 10_000_000e18);
    }

}

contract MainnetController_NFATPrime_Subscribe_Tests is NFATPrime_TestBase {

    function test_subscribeNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribeNFAT_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribeNFAT_zeroFacility() external {
        vm.expectRevert("NFATPrimeFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(0), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribeNFAT_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), 0, "");
    }

    function test_subscribeNFAT_zeroMaxAmount() external {
        // Rate limit is consumed by the actual ALMProxy balance delta post-call, so the
        // zero-maxAmount revert surfaces only after the facility call completes. Zero out the
        // configured limit and exercise that path.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_subscribeNFAT_rateLimitBoundary() external {
        vm.startPrank(allocator);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.nfatPrime_subscribe(address(nfatFacility), 5_000_000e18 + 1, "");

        mainnetController.nfatPrime_subscribe(address(nfatFacility), 5_000_000e18, "");

        vm.stopPrank();
    }

    function test_subscribeNFAT() external {
        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 0);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18);

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),                        10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(nfatFacility.deposits(address(almProxy)),                 SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),             5_000_000e18 - SUBSCRIBE_AMOUNT);
    }

    function test_subscribeNFAT_withData() external {
        bytes memory data = abi.encode("agreement-id-123");

        vm.expectEmit(address(nfatFacility));
        emit NFATFacility.Subscribe(address(almProxy), SUBSCRIBE_AMOUNT, data);

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, data);

        assertEq(nfatFacility.deposits(address(almProxy)), SUBSCRIBE_AMOUNT);
    }

}

contract MainnetController_NFATPrime_Withdraw_Tests is NFATPrime_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), SUBSCRIBE_AMOUNT, "");
    }

    function test_withdrawNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdrawNFAT_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdrawNFAT_zeroFacility() external {
        vm.expectRevert("NFATPrimeFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(0), SUBSCRIBE_AMOUNT);
    }

    function test_withdrawNFAT_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), 0);
    }

    function test_withdrawNFAT_noCode() external {
        // The gem() staticcall is the first thing that touches `facility`; against an EOA the
        // compiler-inserted extcodesize check reverts with empty data before doCall ever runs.
        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(makeAddr("fake-facility"), SUBSCRIBE_AMOUNT);
    }

    function test_withdrawNFAT_zeroMaxAmount() external {
        // Withdraw decrements the rate limit by the actual ALMProxy balance delta post-call;
        // surface the zero-maxAmount revert by zeroing the configured withdraw limit.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(withdrawKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);
    }

    function test_withdrawNFAT_subscribeRefillIsTryIncrease() external {
        // Deploy a facility with a withdraw rate limit but no subscribe key registered. The
        // _tryIncreaseRateLimit on the subscribe key must silently no-op rather than revert.
        NFATFacility nfatFacility2 = new NFATFacility(Ethereum.USDS, "Test NFAT 2", "TNFAT2");

        bytes32 withdrawKey2 =
            mainnetController.nfatPrime_getWithdrawRateLimitKey(address(nfatFacility2), Ethereum.USDS);
        bytes32 subscribeKey2 =
            mainnetController.nfatPrime_getSubscribeRateLimitKey(address(nfatFacility2), Ethereum.USDS);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(withdrawKey2, 5_000_000e18, uint256(1_000_000e18) / 4 hours);

        // Subscribe directly as almProxy to give it deposits to withdraw against.
        vm.startPrank(address(almProxy));
        usds.approve(address(nfatFacility2), SUBSCRIBE_AMOUNT);
        nfatFacility2.subscribe(SUBSCRIBE_AMOUNT, "");
        vm.stopPrank();

        assertEq(rateLimits.getRateLimitData(subscribeKey2).maxAmount, 0);

        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility2), SUBSCRIBE_AMOUNT);

        // No budget was created on the unregistered subscribe key.
        assertEq(rateLimits.getRateLimitData(subscribeKey2).maxAmount, 0);
    }

    function test_withdrawNFAT() external {
        assertEq(usds.balanceOf(address(almProxy)),            10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(nfatFacility.deposits(address(almProxy)),     SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey), 5_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(withdrawKey),  5_000_000e18);

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatPrime_withdraw(address(nfatFacility), SUBSCRIBE_AMOUNT);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),            10_000_000e18);
        assertEq(nfatFacility.deposits(address(almProxy)),     0);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey), 5_000_000e18);
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

    function test_collectNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collectNFAT_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collectNFAT_zeroFacility() external {
        vm.expectRevert("NFATPrimeFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(0), TOKEN_ID, 1_000_000e18);
    }

    function test_collectNFAT_zeroAmount() external {
        vm.expectRevert("NFATPrimeFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_collectNFAT_zeroMaxAmount() external {
        // Collect decrements the rate limit by the actual ALMProxy balance delta post-call;
        // surface the zero-maxAmount revert by zeroing the configured collect limit.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(collectKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);
    }

    function test_collectNFAT_rateLimitBoundary() external {
        vm.startPrank(allocator);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18 + 1);

        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, 1_000_000e18);

        vm.stopPrank();
    }

    function test_collectNFAT() external {
        uint256 collectAmount = 1_000_000e18;

        assertEq(usds.balanceOf(address(almProxy)),             10_000_000e18 - SUBSCRIBE_AMOUNT);
        assertEq(nfatFacility.collectable(TOKEN_ID),            REPAY_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(collectKey),    1_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),  5_000_000e18 - SUBSCRIBE_AMOUNT);

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatPrime_collect(address(nfatFacility), TOKEN_ID, collectAmount);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),             10_000_000e18 - SUBSCRIBE_AMOUNT + collectAmount);
        assertEq(nfatFacility.collectable(TOKEN_ID),            REPAY_AMOUNT - collectAmount);
        assertEq(rateLimits.getCurrentRateLimit(collectKey),    0);
        assertEq(rateLimits.getCurrentRateLimit(subscribeKey),  5_000_000e18 - SUBSCRIBE_AMOUNT + collectAmount);
    }

}
