// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { NFATFacility } from "../../lib/nfat/src/NFATFacility.sol";

import {
    makeAddressAddressUint256Key,
    makeAddressKey
} from "../../src/libraries/RateLimitHelpers.sol";

import { INFATHaloFacet } from "../../src/facets/nfat-halo/INFATHaloFacet.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

abstract contract NFATHalo_TestBase is ForkTestBase {

    NFATFacility internal nfatFacility;
    address      internal nfatRecipient;

    bytes32 internal subscribeKey;
    bytes32 internal interestKey;

    uint256 internal constant ISSUE_AMOUNT    = 1_000_000e18;
    uint256 internal constant INTEREST_BUDGET = 1_000_000e18;
    uint256 internal constant TOKEN_ID        = 1;

    function setUp() public virtual override {
        super.setUp();

        nfatRecipient = makeAddr("nfatRecipient");

        nfatFacility = new NFATFacility(Ethereum.USDS, "Test NFAT", "TNFAT");
        nfatFacility.file("recipient", nfatRecipient);

        // Halo ALMProxy must be a bud on the facility because the facet calls
        // facility.issue via almProxy.doCall.
        nfatFacility.kiss(address(almProxy));

        subscribeKey = makeAddressKey(
            mainnetController.LIMIT_NFAT_PRIME_SUBSCRIBE(),
            address(nfatFacility)
        );
        interestKey = makeAddressAddressUint256Key(
            mainnetController.LIMIT_NFAT_HALO_REPAY_INTEREST(),
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID
        );

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(subscribeKey, 5_000_000e18,    uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(interestKey,  INTEREST_BUDGET, uint256(1_000_000e18) / 4 hours);
        vm.stopPrank();

        deal(Ethereum.USDS, address(almProxy), 5_000_000e18);
    }

}

abstract contract NFATHalo_IssuedPosition_TestBase is NFATHalo_TestBase {

    function setUp() public virtual override {
        super.setUp();

        // Subscribe + issue so a TOKEN_ID position exists with full principal recorded.
        vm.startPrank(allocator);
        mainnetController.subscribeNFAT(address(nfatFacility), ISSUE_AMOUNT, "");
        mainnetController.issueNFAT(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
        vm.stopPrank();
    }

}

contract MainnetController_NFATHalo_Issue_Tests is NFATHalo_TestBase {

    function setUp() public override {
        super.setUp();

        // Pre-fund the facility with a deposit so issue() satisfies deposits[to] >= amount.
        vm.prank(allocator);
        mainnetController.subscribeNFAT(address(nfatFacility), ISSUE_AMOUNT, "");
    }

    function test_issueNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.issueNFAT(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.issueNFAT(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );
    }

    function test_issueNFAT() external {
        // Pre-conditions
        assertEq(usds.balanceOf(address(nfatFacility)),              ISSUE_AMOUNT);
        assertEq(usds.balanceOf(nfatRecipient),                      0);
        assertEq(nfatFacility.deposits(address(almProxy)),           ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipal(TOKEN_ID),       0);
        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), 0);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATIssue(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        vm.record();
        vm.prank(allocator);
        mainnetController.issueNFAT(
            address(nfatFacility),
            address(almProxy),
            TOKEN_ID,
            ISSUE_AMOUNT
        );

        _assertReentrancyGuardWrittenToTwice();

        // Post-conditions
        assertEq(nfatFacility.ownerOf(TOKEN_ID),                     address(almProxy));
        assertEq(usds.balanceOf(address(nfatFacility)),              0);
        assertEq(usds.balanceOf(nfatRecipient),                      ISSUE_AMOUNT);
        assertEq(nfatFacility.deposits(address(almProxy)),           0);
        assertEq(mainnetController.getNFATPrincipal(TOKEN_ID),       ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), 0);
    }

    function test_issueNFAT_multipleTokens() external {
        uint256 firstAmount  = ISSUE_AMOUNT / 4;
        uint256 secondAmount = ISSUE_AMOUNT - firstAmount;

        vm.startPrank(allocator);
        mainnetController.issueNFAT(address(nfatFacility), address(almProxy), 1, firstAmount);
        mainnetController.issueNFAT(address(nfatFacility), address(almProxy), 2, secondAmount);
        vm.stopPrank();

        assertEq(mainnetController.getNFATPrincipal(1), firstAmount);
        assertEq(mainnetController.getNFATPrincipal(2), secondAmount);
    }

}

contract MainnetController_NFATHalo_RepayPrincipal_Tests is NFATHalo_IssuedPosition_TestBase {

    function test_repayPrincipalNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_principalExceededBoundary() external {
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        vm.prank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT + 1);

        // Boundary: exactly equal to remaining principal succeeds.
        vm.prank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);
    }

    function test_repayPrincipalNFAT_multipleIterations() external {
        uint256 chunk = ISSUE_AMOUNT / 4;

        for (uint256 i = 0; i < 4; ++i) {
            vm.prank(allocator);
            mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, chunk);

            assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), chunk * (i + 1));
            // Original principal stays put — only repaid counter moves.
            assertEq(mainnetController.getNFATPrincipal(TOKEN_ID), ISSUE_AMOUNT);
        }

        // Any further principal payment reverts now that the cap is exhausted.
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        vm.prank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayPrincipalNFAT_unknownTokenIdRevertsOnFirstWei() external {
        // No issue() was called for tokenId 99, so principal[99] = 0; any positive amount
        // exceeds the cap immediately.
        vm.expectRevert("NFATHaloFacet/principal-exceeded");
        vm.prank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), 99, 1);
    }

    function test_repayPrincipalNFAT() external {
        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        // Pre
        assertEq(usds.balanceOf(address(nfatFacility)),              0);
        assertEq(nfatFacility.collectable(TOKEN_ID),                 0);
        assertEq(mainnetController.getNFATPrincipal(TOKEN_ID),       ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), 0);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATRepayPrincipal(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        vm.record();
        vm.prank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);

        _assertReentrancyGuardWrittenToTwice();

        // Post
        assertEq(usds.balanceOf(address(almProxy)),                  startingProxyBalance - ISSUE_AMOUNT);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),              ISSUE_AMOUNT);
        assertEq(nfatFacility.collectable(TOKEN_ID),                 ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipal(TOKEN_ID),       ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), ISSUE_AMOUNT);
    }

}

contract MainnetController_NFATHalo_RepayInterest_Tests is NFATHalo_IssuedPosition_TestBase {

    function test_repayInterestNFAT_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, 1);
    }

    function test_repayInterestNFAT_zeroMaxAmount_unconfiguredTokenId() external {
        // The interest rate-limit key is (facility, owner, tokenId). Issuing+owning a token
        // with a different tokenId does not implicitly authorise interest payments against it.
        vm.prank(allocator);
        mainnetController.subscribeNFAT(address(nfatFacility), ISSUE_AMOUNT, "");

        vm.prank(allocator);
        mainnetController.issueNFAT(address(nfatFacility), address(almProxy), 2, ISSUE_AMOUNT);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.repayInterestNFAT(address(nfatFacility), 2, 1);
    }

    function test_repayInterestNFAT_rateLimitBoundary() external {
        vm.startPrank(allocator);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET + 1);

        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET);

        vm.stopPrank();
    }

    function test_repayInterestNFAT_doesNotChangePrincipalCounters() external {
        vm.prank(allocator);
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET);

        assertEq(mainnetController.getNFATPrincipal(TOKEN_ID),       ISSUE_AMOUNT);
        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), 0);
    }

    function test_repayInterestNFAT_independentOfPrincipalState() external {
        // Interest can be paid even after principal is fully repaid (and vice versa).
        vm.startPrank(allocator);
        mainnetController.repayPrincipalNFAT(address(nfatFacility), TOKEN_ID, ISSUE_AMOUNT);
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET);
        vm.stopPrank();

        assertEq(mainnetController.getNFATPrincipalRepaid(TOKEN_ID), ISSUE_AMOUNT);
        assertEq(rateLimits.getCurrentRateLimit(interestKey),        0);
    }

    function test_repayInterestNFAT() external {
        uint256 startingProxyBalance = usds.balanceOf(address(almProxy));

        // Pre
        assertEq(usds.balanceOf(address(nfatFacility)),       0);
        assertEq(nfatFacility.collectable(TOKEN_ID),          0);
        assertEq(rateLimits.getCurrentRateLimit(interestKey), INTEREST_BUDGET);

        vm.expectEmit(address(mainnetController));
        emit INFATHaloFacet.NFATRepayInterest(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET);

        vm.record();
        vm.prank(allocator);
        mainnetController.repayInterestNFAT(address(nfatFacility), TOKEN_ID, INTEREST_BUDGET);

        _assertReentrancyGuardWrittenToTwice();

        // Post
        assertEq(usds.balanceOf(address(almProxy)),           startingProxyBalance - INTEREST_BUDGET);
        assertEq(usds.allowance(address(almProxy), address(nfatFacility)), 0);
        assertEq(usds.balanceOf(address(nfatFacility)),       INTEREST_BUDGET);
        assertEq(nfatFacility.collectable(TOKEN_ID),          INTEREST_BUDGET);
        assertEq(rateLimits.getCurrentRateLimit(interestKey), 0);
    }

}
