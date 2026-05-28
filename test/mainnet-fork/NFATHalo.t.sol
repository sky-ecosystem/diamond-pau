// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { NFATFacility } from "../../lib/nfat/src/NFATFacility.sol";

import { INFATHaloFacet } from "../../src/facets/nfat-halo/INFATHaloFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

abstract contract NFATHalo_TestBase is ForkTestBase {

    NFATFacility internal nfatFacility;

    bytes32 internal subscribeKey;
    bytes32 internal issueKey;
    bytes32 internal repayPrincipalKey;
    bytes32 internal repayInterestKey;

    uint256 internal constant ISSUE_AMOUNT        = 1_000_000e18;
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

        subscribeKey =
            mainnetController.nfatPrime_getSubscribeRateLimitKey(address(nfatFacility), Ethereum.USDS);
        issueKey = mainnetController.nfatHalo_getIssueRateLimitKey(
            address(nfatFacility),
            Ethereum.USDS,
            address(almProxy)
        );
        repayPrincipalKey =
            mainnetController.nfatHalo_getRepayPrincipalRateLimitKey(address(nfatFacility), Ethereum.USDS);
        repayInterestKey =
            mainnetController.nfatHalo_getRepayInterestRateLimitKey(address(nfatFacility), Ethereum.USDS);

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey,      5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(issueKey,          5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(repayPrincipalKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(repayInterestKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), ANNUAL_GROWTH_RATE);
        vm.stopPrank();

        deal(Ethereum.USDS, address(almProxy), 5_000_000e18);
    }

}

abstract contract NFATHalo_IssuedPosition_TestBase is NFATHalo_TestBase {

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

contract MainnetController_NFATHalo_SetAnnualGrowthRate_Tests is NFATHalo_TestBase {

    function test_setAnnualGrowthRateNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), ANNUAL_GROWTH_RATE);
    }

    function test_setAnnualGrowthRateNFAT_notAdmin() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), ANNUAL_GROWTH_RATE);
    }

    function test_setAnnualGrowthRateNFAT_zeroFacility() external {
        vm.expectRevert("NFATHaloFacet/facility-zero-address");
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.nfatHalo_setAnnualGrowthRate(address(0), ANNUAL_GROWTH_RATE);
    }

    function test_setAnnualGrowthRateNFAT() external {
        // Pre-state set by base setUp.
        assertEq(
            mainnetController.nfatHalo_getAnnualGrowthRate(address(nfatFacility)),
            ANNUAL_GROWTH_RATE
        );

        uint256 newRate = 0.50e18;

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloAnnualGrowthRateSet(address(nfatFacility), newRate);

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), newRate);

        assertEq(mainnetController.nfatHalo_getAnnualGrowthRate(address(nfatFacility)), newRate);
    }

    function test_setAnnualGrowthRateNFAT_sameBlockUpdate() external {
        // First call in setUp checkpointed the facility at the current timestamp; a second
        // call in the same block should hit the lastUpdated == block.timestamp early return
        // in _checkpointFacility and leave the interest index unchanged.
        uint256 indexBefore = mainnetController.nfatHalo_getInterestIndex(address(nfatFacility));

        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.nfatHalo_setAnnualGrowthRate(address(nfatFacility), 0.50e18);

        assertEq(mainnetController.nfatHalo_getAnnualGrowthRate(address(nfatFacility)), 0.50e18);
        assertEq(mainnetController.nfatHalo_getInterestIndex(address(nfatFacility)), indexBefore);
    }

}

contract MainnetController_NFATHalo_Views_Tests is NFATHalo_TestBase {

    function test_getInterestIndexNFAT_initial() external view {
        // setUp called setAnnualGrowthRate, which checkpoints at lastUpdated=now with
        // interestIndex=0. No time elapsed → still 0.
        assertEq(mainnetController.nfatHalo_getInterestIndex(address(nfatFacility)), 0);
    }

    function test_getInterestIndexNFAT_accruesOverTime() external {
        vm.warp(block.timestamp + 365 days);

        // After a full year at 20% APR, the cumulative index is 0.20e18.
        assertEq(
            mainnetController.nfatHalo_getInterestIndex(address(nfatFacility)),
            ANNUAL_GROWTH_RATE
        );
    }

    function test_getInterestIndexNFAT_unconfiguredFacility() external {
        // A facility with no setAnnualGrowthRate call has lastUpdated == 0; the early return
        // in _getCurrentInterestIndex hands back the stored interestIndex of 0.
        address otherFacility = makeAddr("otherFacility");
        assertEq(mainnetController.nfatHalo_getInterestIndex(otherFacility), 0);
    }

    function test_getInterestAvailableNFAT_unissued() external view {
        // !position.issued early return in getInterestAvailable yields 0.
        assertEq(mainnetController.nfatHalo_getInterestAvailable(address(nfatFacility), TOKEN_ID), 0);
    }

    function test_getRateLimitKeys_areDeterministic() external {
        address otherFacility = makeAddr("otherFacility");

        assertEq(
            mainnetController.nfatHalo_getIssueRateLimitKey(
                address(nfatFacility),
                Ethereum.USDS,
                address(almProxy)
            ),
            issueKey
        );
        assertEq(
            mainnetController.nfatHalo_getRepayPrincipalRateLimitKey(address(nfatFacility), Ethereum.USDS),
            repayPrincipalKey
        );
        assertEq(
            mainnetController.nfatHalo_getRepayInterestRateLimitKey(address(nfatFacility), Ethereum.USDS),
            repayInterestKey
        );

        // Different facility → different key.
        assertTrue(
            mainnetController.nfatHalo_getIssueRateLimitKey(
                otherFacility,
                Ethereum.USDS,
                address(almProxy)
            ) != issueKey
        );
    }

}

contract MainnetController_NFATHalo_Issue_Tests is NFATHalo_TestBase {

    function setUp() public override {
        super.setUp();

        // Pre-fund the facility with a deposit so issue() satisfies deposits[to] >= amount.
        vm.prank(allocator);
        mainnetController.nfatPrime_subscribe(address(nfatFacility), ISSUE_AMOUNT, "");
    }

    function test_issueNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT_notAllocator() external {
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

    function test_issueNFAT_zeroFacility() external {
        vm.expectRevert("NFATHaloFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(address(0), address(almProxy), TOKEN_ID, ISSUE_AMOUNT);
    }

    function test_issueNFAT_recipientMismatch() external {
        // Point the facility's gem recipient somewhere other than the ALMProxy and verify the
        // recipient-mismatch guard fires.
        nfatFacility.file("recipient", makeAddr("notProxy"));

        vm.expectRevert("NFATHaloFacet/recipient-mismatch");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT_zeroMaxAmount() external {
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

    function test_issueNFAT_alreadyIssued() external {
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        // Top up the budget for the second attempt so we exercise the position-exists check
        // rather than the rate-limit check.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(issueKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);

        vm.expectRevert("NFATHaloFacet/position-exists");
        vm.prank(allocator);
        mainnetController.nfatHalo_issue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT() external {
        // Pre-conditions: setUp dealt 5M USDS to almProxy and subscribed ISSUE_AMOUNT into the
        // facility, so the facility holds ISSUE_AMOUNT and almProxy holds 5M - ISSUE_AMOUNT.
        assertEq(usds.balanceOf(address(nfatFacility)),    ISSUE_AMOUNT);
        assertEq(usds.balanceOf(address(almProxy)),        5_000_000e18 - ISSUE_AMOUNT);
        assertEq(nfatFacility.deposits(address(almProxy)), ISSUE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(issueKey), 5_000_000e18);

        INFATHaloFacet.Position memory before =
            mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);
        assertEq(before.issued,          false);
        assertEq(before.principal,       0);
        assertEq(before.principalRepaid, 0);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloIssue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            Ethereum.USDS,
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

        INFATHaloFacet.Position memory pos =
            mainnetController.nfatHalo_getPosition(address(nfatFacility), TOKEN_ID);
        assertEq(pos.issued,          true);
        assertEq(pos.principal,       ISSUE_AMOUNT);
        assertEq(pos.principalRepaid, 0);
        assertEq(pos.accruedInterest, 0);

        assertEq(
            mainnetController.nfatHalo_getPrincipalOutstanding(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT_multipleTokens() external {
        uint256 firstAmount  = ISSUE_AMOUNT / 4;
        uint256 secondAmount = ISSUE_AMOUNT - firstAmount;

        vm.startPrank(allocator);
        mainnetController.nfatHalo_issue(address(nfatFacility), address(almProxy), 1, firstAmount);
        mainnetController.nfatHalo_issue(address(nfatFacility), address(almProxy), 2, secondAmount);
        vm.stopPrank();

        assertEq(mainnetController.nfatHalo_getPrincipal(address(nfatFacility), 1), firstAmount);
        assertEq(mainnetController.nfatHalo_getPrincipal(address(nfatFacility), 2), secondAmount);
    }

}

contract MainnetController_NFATHalo_RepayPrincipal_Tests is NFATHalo_IssuedPosition_TestBase {

    function test_repayPrincipalNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_zeroFacility() external {
        vm.expectRevert("NFATHaloFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(0), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_zeroAmount() external {
        vm.expectRevert("NFATHaloFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_repayPrincipalNFAT_zeroMaxAmount() external {
        // The repay-principal rate limit is decremented by the actual ALMProxy balance delta
        // post-call, so the zero-maxAmount revert surfaces only after the facility repay
        // completes. Zero out the configured limit on the established position to exercise it.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayPrincipalKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_unknownTokenId() external {
        vm.expectRevert("NFATHaloFacet/position-not-found");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), 99, 1);
    }

    function test_repayPrincipalNFAT_principalExceededBoundary() external {
        vm.prank(allocator);
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT + 1);

        // Boundary: exactly equal to remaining principal succeeds.
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);
    }

    function test_repayPrincipalNFAT_multipleIterations() external {
        uint256 chunk = ISSUE_AMOUNT / 4;

        for (uint256 i = 0; i < 4; ++i) {
            vm.prank(allocator);
            mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, chunk);

            assertEq(
                mainnetController.nfatHalo_getPrincipalRepaid(address(nfatFacility), TOKEN_ID),
                chunk * (i + 1)
            );
            // Original principal stays put — only repaid counter moves.
            assertEq(
                mainnetController.nfatHalo_getPrincipal(address(nfatFacility), TOKEN_ID),
                ISSUE_AMOUNT
            );
        }

        // Any further principal payment reverts now that the cap is exhausted.
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT() external {
        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        // Pre
        assertEq(usds.balanceOf(address(nfatFacility)),             0);
        assertEq(nfatFacility.collectable(TOKEN_ID),                0);
        assertEq(rateLimits.getCurrentRateLimit(repayPrincipalKey), 5_000_000e18);
        assertEq(
            mainnetController.nfatHalo_getPrincipal(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
        assertEq(
            mainnetController.nfatHalo_getPrincipalRepaid(address(nfatFacility), TOKEN_ID),
            0
        );

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayPrincipal(
            address(nfatFacility),
            Ethereum.USDS,
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        vm.record();
        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        _assertReentrancyGuardWrittenToTwice();

        // Post
        assertEq(usds.balanceOf(address(almProxy)),                        startingProxyBalance - ISSUE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),                    ISSUE_AMOUNT);
        assertEq(nfatFacility.collectable(TOKEN_ID),                       ISSUE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(repayPrincipalKey),        5_000_000e18 - ISSUE_AMOUNT);
        assertEq(
            mainnetController.nfatHalo_getPrincipal(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
        assertEq(
            mainnetController.nfatHalo_getPrincipalRepaid(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
        assertEq(
            mainnetController.nfatHalo_getPrincipalOutstanding(address(nfatFacility), TOKEN_ID),
            0
        );
    }

}

contract MainnetController_NFATHalo_RepayInterest_Tests is NFATHalo_IssuedPosition_TestBase {

    uint256 internal constant ELAPSED          = 365 days;
    // ISSUE_AMOUNT * (ANNUAL_GROWTH_RATE * ELAPSED / 365 days) / 1e18 == ISSUE_AMOUNT * 0.20.
    uint256 internal constant EXPECTED_ACCRUED = ISSUE_AMOUNT * ANNUAL_GROWTH_RATE / 1e18;

    function setUp() public override {
        super.setUp();
        // Warp forward one year so a full APR's worth of interest has accrued on the position.
        vm.warp(block.timestamp + ELAPSED);
    }

    function test_repayInterestNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_zeroFacility() external {
        vm.expectRevert("NFATHaloFacet/facility-zero-address");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(0), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_zeroAmount() external {
        vm.expectRevert("NFATHaloFacet/zero-amount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 0);
    }

    function test_repayInterestNFAT_zeroMaxAmount() external {
        // The repay-interest rate limit is decremented by the actual ALMProxy balance delta
        // post-call, so the zero-maxAmount revert surfaces only after the facility repay
        // completes. Zero out the configured limit on the established position to exercise it.
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(repayInterestKey, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_unknownTokenId() external {
        vm.expectRevert("NFATHaloFacet/position-not-found");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), 99, 1);
    }

    function test_repayInterestNFAT_interestExceededBoundary() external {
        // Boundary: exactly equal to currently-accrued interest succeeds; one wei over reverts.
        vm.expectRevert("NFATHaloFacet/interest-exceeded");
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, EXPECTED_ACCRUED + 1);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, EXPECTED_ACCRUED);
    }

    function test_repayInterestNFAT_doesNotChangePrincipalCounters() external {
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, EXPECTED_ACCRUED);

        assertEq(
            mainnetController.nfatHalo_getPrincipal(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
        assertEq(
            mainnetController.nfatHalo_getPrincipalRepaid(address(nfatFacility), TOKEN_ID),
            0
        );
    }

    function test_repayInterestNFAT_independentOfPrincipalState() external {
        // Once principal is fully repaid, outstanding goes to zero so no further interest can
        // accrue — but previously-accrued interest is still owed and repayable.
        uint256 accruedBefore =
            mainnetController.nfatHalo_getInterestAvailable(address(nfatFacility), TOKEN_ID);
        assertEq(accruedBefore, EXPECTED_ACCRUED);

        vm.prank(allocator);
        mainnetController.nfatHalo_repayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        // Repaying principal triggers a checkpoint that captures the EXPECTED_ACCRUED interest.
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, EXPECTED_ACCRUED);

        assertEq(
            mainnetController.nfatHalo_getPrincipalRepaid(address(nfatFacility), TOKEN_ID),
            ISSUE_AMOUNT
        );
        assertEq(
            mainnetController.nfatHalo_getInterestAvailable(address(nfatFacility), TOKEN_ID),
            0
        );
    }

    function test_repayInterestNFAT() external {
        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        // Pre
        assertEq(usds.balanceOf(address(nfatFacility)),               0);
        assertEq(nfatFacility.collectable(TOKEN_ID),                  0);
        assertEq(rateLimits.getCurrentRateLimit(repayInterestKey),    5_000_000e18);
        assertEq(
            mainnetController.nfatHalo_getInterestAvailable(address(nfatFacility), TOKEN_ID),
            EXPECTED_ACCRUED
        );

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATHaloRepayInterest(
            address(nfatFacility),
            Ethereum.USDS,
            TOKEN_ID,
            EXPECTED_ACCRUED
        );

        vm.record();
        vm.prank(allocator);
        mainnetController.nfatHalo_repayInterest(address(nfatFacility), TOKEN_ID, EXPECTED_ACCRUED);

        _assertReentrancyGuardWrittenToTwice();

        // Post
        assertEq(usds.balanceOf(address(almProxy)),                        startingProxyBalance - EXPECTED_ACCRUED);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),                    EXPECTED_ACCRUED);
        assertEq(nfatFacility.collectable(TOKEN_ID),                       EXPECTED_ACCRUED);
        assertEq(rateLimits.getCurrentRateLimit(repayInterestKey),         5_000_000e18 - EXPECTED_ACCRUED);
        assertEq(
            mainnetController.nfatHalo_getInterestAvailable(address(nfatFacility), TOKEN_ID),
            0
        );
    }

}
