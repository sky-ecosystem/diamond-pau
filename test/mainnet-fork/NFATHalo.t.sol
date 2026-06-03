// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { NFATFacility } from "../../lib/nfat/src/NFATFacility.sol";

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { INFATHaloFacet } from "../../src/facets/nfat-halo/INFATHaloFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

abstract contract NFATHalo_TestBase is ForkTestBase {

    NFATFacility internal nfatFacility;

    bytes32 internal subscribeKey;
    bytes32 internal issueKey;
    bytes32 internal repayPrincipalKey;
    bytes32 internal repayInterestKey;

    uint256 internal constant ANNUAL_GROWTH_RATE  = 0.20e18;  // 20% APR
    uint256 internal constant TOKEN_ID            = 1;

    function setUp() public virtual override {
        super.setUp();

        nfatFacility = new NFATFacility(Ethereum.USDS, "Test NFAT", "TNFAT");

        // Halo issue requires recipient == ALMProxy so the principal lands back in our custody
        // and the rate-limit delta can be measured against the ALMProxy balance.
        nfatFacility.file("recipient", address(almProxy));

        // Halo ALMProxy must be a bud on the facility because the facet calls
        // facility.issue / facility.repay via almProxy.doCall.
        nfatFacility.kiss(address(almProxy));

        subscribeKey = mainnetController.nfatPrime_getSubscribeRateLimitKey(address(nfatFacility), Ethereum.USDS);

        issueKey = mainnetController.nfatHalo_getIssueRateLimitKey(
            address(nfatFacility),
            Ethereum.USDS,
            address(almProxy)
        );

        repayPrincipalKey = mainnetController.nfatHalo_getRepayPrincipalRateLimitKey(address(nfatFacility), Ethereum.USDS);

        repayInterestKey = mainnetController.nfatHalo_getRepayInterestRateLimitKey(address(nfatFacility), Ethereum.USDS);

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setUnlimitedRateLimitData(subscribeKey);
        rateLimits.setUnlimitedRateLimitData(issueKey);
        rateLimits.setUnlimitedRateLimitData(repayPrincipalKey);
        rateLimits.setUnlimitedRateLimitData(repayInterestKey);

        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), ANNUAL_GROWTH_RATE);

        vm.stopPrank();

        deal(Ethereum.USDS, address(almProxy), 5_000_000e18);
    }

}

contract MainnetController_NFATHalo_Issue_Tests is NFATHalo_TestBase {

    uint256 internal constant ISSUE_AMOUNT = 1_000_000e18;

    function setUp() public override {
        super.setUp();

        // Pre-fund the facility with a deposit so issue() satisfies deposits[to] >= amount.
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), ISSUE_AMOUNT, "");
    }

    function test_issue_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issue_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issue_amountZero() external {
        vm.expectRevert("NFATHaloFacet/amount-zero");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(address(nfatFacility), address(almProxy), TOKEN_ID, 0);
    }

    function test_issue_alreadyIssued() external {
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        vm.expectRevert("NFATHaloFacet/position-exists");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issue_zeroMaxAmount() external {
        // The (facility, almProxy) issue limit is consumed by the ALMProxy balance delta after
        // the facility call lands, so zero out the existing limit to exercise that revert.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(issueKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issue_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(issueKey, ISSUE_AMOUNT - 1, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(issueKey, ISSUE_AMOUNT, 0);

        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issue() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(issueKey, 5_000_000e18, 0);

        // Pre-conditions: setUp dealt 5M USDS to almProxy and subscribed ISSUE_AMOUNT into the
        // facility, so the facility holds ISSUE_AMOUNT and almProxy holds 5M - ISSUE_AMOUNT.
        assertEq(usds.balanceOf(address(nfatFacility)),    ISSUE_AMOUNT);
        assertEq(usds.balanceOf(address(almProxy)),        5_000_000e18 - ISSUE_AMOUNT);
        assertEq(nfatFacility.deposits(address(almProxy)), ISSUE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(issueKey), 5_000_000e18);

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 interestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,               false);
        assertEq(outstandingPrincipal, 0);
        assertEq(outstandingInterest,  0);
        assertEq(interestIndex,        0);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloIssue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        _assertReentrancyGuardWrittenToTwice();

        // Post-conditions: facility transferred its ISSUE_AMOUNT of gem to recipient=almProxy,
        // bringing almProxy's balance back to the original 5M.
        assertEq(nfatFacility.ownerOf(TOKEN_ID),           address(almProxy));
        assertEq(usds.balanceOf(address(nfatFacility)),    0);
        assertEq(usds.balanceOf(address(almProxy)),        5_000_000e18);
        assertEq(nfatFacility.deposits(address(almProxy)), 0);
        assertEq(rateLimits.getCurrentRateLimit(issueKey), 5_000_000e18 - ISSUE_AMOUNT);

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            interestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,               true);
        assertEq(outstandingPrincipal, ISSUE_AMOUNT);
        assertEq(outstandingInterest,  0);
        assertEq(interestIndex,        0);
    }

    function test_issue_multipleTokens() external {
        uint256 firstAmount  = ISSUE_AMOUNT / 4;
        uint256 secondAmount = ISSUE_AMOUNT - firstAmount;

        vm.startPrank(allocator);
        mainnetController.nfatHalo_issue(address(nfatFacility), address(almProxy), 1, firstAmount);
        mainnetController.nfatHalo_issue(address(nfatFacility), address(almProxy), 2, secondAmount);
        vm.stopPrank();

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 interestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), 1);

        assertEq(issued,               true);
        assertEq(outstandingPrincipal, firstAmount);
        assertEq(outstandingInterest,  0);
        assertEq(interestIndex,        0);

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            interestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), 2);

        assertEq(issued,               true);
        assertEq(outstandingPrincipal, secondAmount);
        assertEq(outstandingInterest,  0);
        assertEq(interestIndex,        0);
    }

}

abstract contract NFATHalo_Repay_TestBase is NFATHalo_TestBase {

    uint256 internal constant ISSUE_AMOUNT = 1_000_000e18;

    function setUp() public virtual override {
        super.setUp();

        // Subscribe + issue so a TOKEN_ID position exists with full principal recorded.
        vm.startPrank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), ISSUE_AMOUNT, "");
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
        vm.stopPrank();
    }

}

contract MainnetController_NFATHalo_RepayPrincipal_Tests is NFATHalo_Repay_TestBase {

    function test_repayPrincipal_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipal_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipal_zeroAmount() external {
        vm.expectRevert("NFATHaloFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_repayPrincipal_positionNotFound() external {
        vm.expectRevert("NFATHaloFacet/position-not-found");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), 99, 1);
    }

    function test_repayPrincipal_principalExceededBoundary() external {
        vm.prank(allocator);
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT + 1);

        // Boundary: exactly equal to remaining principal succeeds.
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);
    }

    function test_repayPrincipal_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayPrincipalKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipal_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayPrincipalKey, 50_000e18, 0);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 50_000e18 + 1);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 50_000e18);
    }

    function test_repayPrincipal() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayPrincipalKey, 5_000_000e18, 0);

        uint256 startTimestamp = vm.getBlockTimestamp();

        vm.warp(startTimestamp + 180 days);

        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        assertEq(usds.balanceOf(address(nfatFacility)),             0);
        assertEq(rateLimits.getCurrentRateLimit(repayPrincipalKey), 5_000_000e18);

        ( uint256 facilityInterestIndex, uint256 lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0);
        assertEq(lastUpdated,           startTimestamp);

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),                        startingProxyBalance - ISSUE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),                    ISSUE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(repayPrincipalKey),        5_000_000e18 - ISSUE_AMOUNT);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.098630136986301369e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  0);
        assertEq(outstandingInterest,   98_630.136986301369e18);
        assertEq(positionInterestIndex, 0.098630136986301369e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);
    }

    function test_repayPrincipal_multiple() external {
        uint256 firstAmount  = ISSUE_AMOUNT / 2;
        uint256 secondAmount = ISSUE_AMOUNT - firstAmount;

        uint256 startTimestamp = vm.getBlockTimestamp();

        // Make first principal repayment in 180 days so interest has accrued.
        vm.warp(startTimestamp + 180 days);

        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        assertEq(usds.balanceOf(address(nfatFacility)), 0);

        ( uint256 facilityInterestIndex, uint256 lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0);
        assertEq(lastUpdated,           startTimestamp);

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayPrincipal(address(nfatFacility), TOKEN_ID, firstAmount);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, firstAmount);

        assertEq(usds.balanceOf(address(almProxy)),     startingProxyBalance - firstAmount);
        assertEq(usds.balanceOf(address(nfatFacility)), firstAmount);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.098630136986301369e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT - firstAmount);
        assertEq(outstandingInterest,   98_630.136986301369e18);
        assertEq(positionInterestIndex, 0.098630136986301369e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);

        // Make second principal repayment in 180 days so interest has accrued.
        vm.warp(startTimestamp + 360 days);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 147_945.2054794520535e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayPrincipal(address(nfatFacility), TOKEN_ID, secondAmount);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, secondAmount);

        assertEq(usds.balanceOf(address(almProxy)),     startingProxyBalance - firstAmount - secondAmount);
        assertEq(usds.balanceOf(address(nfatFacility)), firstAmount + secondAmount);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.197260273972602738e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  0);
        assertEq(outstandingInterest,   147_945.2054794520535e18);
        assertEq(positionInterestIndex, 0.197260273972602738e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 147_945.2054794520535e18);
    }

}

contract MainnetController_NFATHalo_RepayInterest_Tests is NFATHalo_Repay_TestBase {

    function test_repayInterest_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterest_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterest_zeroAmount() external {
        vm.expectRevert("NFATHaloFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_repayInterest_positionNotFound() external {
        vm.expectRevert("NFATHaloFacet/position-not-found");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), 99, 1);
    }

    function test_repayInterest_interestExceededBoundary() external {
        vm.warp(vm.getBlockTimestamp() + 180 days);

        vm.prank(allocator);
        vm.expectRevert("NFATHaloFacet/interest-exceeded");
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 98_630.136986301369e18 + 1);

        // Boundary: exactly equal to remaining principal succeeds.
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 98_630.136986301369e18);
    }

    function test_repayInterest_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayInterestKey, 0, 0);

        vm.warp(vm.getBlockTimestamp() + 180 days);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterest_rateLimitBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayInterestKey, 50_000e18, 0);

        vm.warp(vm.getBlockTimestamp() + 180 days);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 50_000e18 + 1);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 50_000e18);
    }

    function test_repayInterest() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayInterestKey, 5_000_000e18, 0);

        uint256 startTimestamp = vm.getBlockTimestamp();

        vm.warp(startTimestamp + 180 days);

        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        assertEq(usds.balanceOf(address(nfatFacility)),             0);
        assertEq(rateLimits.getCurrentRateLimit(repayInterestKey), 5_000_000e18);

        ( uint256 facilityInterestIndex, uint256 lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0);
        assertEq(lastUpdated,           startTimestamp);

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayInterest(address(nfatFacility), TOKEN_ID, 98_630.136986301369e18);

        vm.record();

        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 98_630.136986301369e18);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(usds.balanceOf(address(almProxy)),                        startingProxyBalance - 98_630.136986301369e18);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),                    98_630.136986301369e18);
        assertEq(rateLimits.getCurrentRateLimit(repayInterestKey),         5_000_000e18 - 98_630.136986301369e18);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.098630136986301369e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0.098630136986301369e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 0);
    }

    function test_repayInterest_multiple_xxx() external {
        uint256 startTimestamp = vm.getBlockTimestamp();

        // Make first interest repayment in 180 days so interest has accrued.
        vm.warp(startTimestamp + 180 days);

        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        assertEq(usds.balanceOf(address(nfatFacility)), 0);

        ( uint256 facilityInterestIndex, uint256 lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0);
        assertEq(lastUpdated,           startTimestamp);

        (
            bool    issued,
            uint256 outstandingPrincipal,
            uint256 outstandingInterest,
            uint256 positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayInterest(address(nfatFacility), TOKEN_ID, 50_000e18);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 50_000e18);

        assertEq(usds.balanceOf(address(almProxy)),     startingProxyBalance - 50_000e18);
        assertEq(usds.balanceOf(address(nfatFacility)), 50_000e18);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.098630136986301369e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   98_630.136986301369e18 - 50_000e18);
        assertEq(positionInterestIndex, 0.098630136986301369e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 98_630.136986301369e18 - 50_000e18);

        // Make second interest repayment in 180 days so interest has accrued.
        vm.warp(startTimestamp + 360 days);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 147_260.273972602738e18);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayInterest(address(nfatFacility), TOKEN_ID, 147_260.273972602738e18);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 147_260.273972602738e18);

        assertEq(usds.balanceOf(address(almProxy)),     startingProxyBalance - 50_000e18 - 147_260.273972602738e18);
        assertEq(usds.balanceOf(address(nfatFacility)), 50_000e18 + 147_260.273972602738e18);

        ( facilityInterestIndex, lastUpdated ) = mainnetController.nfatHalo_getFacilityState(address(nfatFacility));

        assertEq(facilityInterestIndex, 0.197260273972602738e18);
        assertEq(lastUpdated,           vm.getBlockTimestamp());

        (
            issued,
            outstandingPrincipal,
            outstandingInterest,
            positionInterestIndex
        ) = mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);

        assertEq(issued,                true);
        assertEq(outstandingPrincipal,  ISSUE_AMOUNT);
        assertEq(outstandingInterest,   0);
        assertEq(positionInterestIndex, 0.197260273972602738e18);

        assertEq(mainnetController.nfatHalo_getCurrentOutstandingInterest(address(nfatFacility), TOKEN_ID), 0);
    }

}
