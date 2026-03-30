// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import {
    ICentrifugeV3VaultLike,
    IERC20MintableLike,
    IInvestmentManagerLike,
    IRestrictionManagerLike
} from "../interfaces/Centrifuge.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

abstract contract Centrifuge_TestBase is ForkTestBase {

    address constant ESCROW                         = 0x0000000005F458Fd6ba9EEb5f365D83b7dA913dD;
    address constant INVESTMENT_MANAGER             = 0x427A1ce127b1775e4Cbd4F58ad468B9F832eA7e9;
    address constant JTREASURY_RESTRICTION_MANAGER  = 0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0;
    address constant JTREASURY_TOKEN                = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
    address constant JTREASURY_VAULT_USDC           = 0x36036fFd9B1C6966ab23209E073c68Eb9A992f50;
    address constant ROOT                           = 0x0C1fDfd6a1331a875EA013F3897fc8a76ada5DfC;

    bytes16 constant JTREASURY_TRANCHE_ID = 0x97aa65f23e7be09fcd62d0554d2e9273;
    uint128 constant USDC_ASSET_ID        = 242333941209166991950178742833476896417;
    uint64  constant JTREASURY_POOL_ID    = 4139607887;

    // Requests for Centrifuge pools are non-fungible and all have ID = 0
    uint256 constant REQUEST_ID = 0;

    IInvestmentManagerLike  internal investmentManager  = IInvestmentManagerLike(INVESTMENT_MANAGER);
    IRestrictionManagerLike internal restrictionManager = IRestrictionManagerLike(JTREASURY_RESTRICTION_MANAGER);

    ICentrifugeV3VaultLike internal jTreasuryVault = ICentrifugeV3VaultLike(JTREASURY_VAULT_USDC);
    IERC20MintableLike     internal jTreasuryToken = IERC20MintableLike(JTREASURY_TOKEN);

    address internal unauthorized = makeAddr("unauthorized");

    function _getBlock() internal pure override returns (uint256) {
        return 21988625;  // Mar 6, 2025
    }

}

contract MainnetController_Centrifuge_RequestDepositERC7540_Tests is Centrifuge_TestBase {

    bytes32 internal key;

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        key = makeAddressKey(
            mainnetController.LIMIT_7540_DEPOSIT(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);

        deal(address(usdc), almProxy, 1_000_000e6);
    }

    function test_requestDepositERC7540_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);
    }

    function test_requestDepositERC7540_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);
    }

    function test_requestDepositERC7540_rateLimitBoundary() external {
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6 + 1);

        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);
    }

    function test_requestDepositERC7540() external {
        deal(address(usdc), almProxy, 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 1_000_000e6);

        assertEq(usdc.allowance(almProxy, address(jTreasuryVault)), 0);

        uint256 initialEscrowBal = usdc.balanceOf(ESCROW);

        assertEq(usdc.balanceOf(almProxy), 1_000_000e6);
        assertEq(usdc.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy), 0);

        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);

        assertEq(usdc.allowance(almProxy, address(jTreasuryVault)), 0);

        assertEq(usdc.balanceOf(almProxy), 0);
        assertEq(usdc.balanceOf(ESCROW),   initialEscrowBal + 1_000_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy), 1_000_000e6);
    }

}

contract MainnetController_Centrifuge_ClaimDepositERC7540_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_DEPOSIT(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_500_000e6, uint256(1_500_000e6) / 1 days);
    }

    function test_claimDepositERC7540_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.claimDepositERC7540(address(jTreasuryVault));
    }

    function test_claimDepositERC7540_invalidVault() external {
        vm.expectRevert("ERC7540Facet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.claimDepositERC7540(makeAddr("fake-vault"));
    }

    function test_claimDepositERC7540_singleRequest() external {
        deal(address(usdc), almProxy, 1_000_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);

        // Request deposit into JTRSY by supplying USDC
        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);

        uint256 totalSupply = jTreasuryToken.totalSupply();

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   1_000_000e6);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);

        // Fulfill request at price 2.0
        vm.prank(ROOT);
        investmentManager.fulfillDepositRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            1_000_000e6,
            500_000e6
        );

        assertEq(jTreasuryToken.totalSupply(),       totalSupply + 500_000e6);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + 500_000e6);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 1_000_000e6);

        // Claim shares
        vm.prank(RELAYER);
        mainnetController.claimDepositERC7540(address(jTreasuryVault));

        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
        assertEq(jTreasuryToken.balanceOf(almProxy), 500_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);
    }

    function test_claimDepositERC7540_multipleRequests() external {
        deal(address(usdc), almProxy, 1_500_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);

        // Request deposit into JTRSY by supplying USDC
        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);

        uint256 totalSupply = jTreasuryToken.totalSupply();

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   1_000_000e6);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);

        // Request another deposit into JTRSY by supplying more USDC
        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 500_000e6);

        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   1_500_000e6);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);

        // Fulfill both requests at price 2.0
        vm.prank(ROOT);
        investmentManager.fulfillDepositRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            1_500_000e6,
            750_000e6
        );

        assertEq(jTreasuryToken.totalSupply(),       totalSupply + 750_000e6);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + 750_000e6);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 1_500_000e6);

        // Claim shares
        vm.prank(RELAYER);
        mainnetController.claimDepositERC7540(address(jTreasuryVault));

        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
        assertEq(jTreasuryToken.balanceOf(almProxy), 750_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableDepositRequest(REQUEST_ID, almProxy), 0);
    }

}

contract MainnetController_Centrifuge_CancelDeposit_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_DEPOSIT(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);
    }

    function test_cancelCentrifugeDepositRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.cancelCentrifugeDepositRequest(address(jTreasuryVault));
    }

    function test_cancelCentrifugeDepositRequest_invalidVault() external {
        vm.expectRevert("CentrifugeFacet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.cancelCentrifugeDepositRequest(makeAddr("fake-vault"));
    }

    function test_cancelCentrifugeDepositRequest() external {
        deal(address(usdc), almProxy, 1_000_000e6);

        vm.prank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),       1_000_000e6);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy), false);

        vm.prank(RELAYER);
        mainnetController.cancelCentrifugeDepositRequest(address(jTreasuryVault));

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),       1_000_000e6);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy), true);
    }

}

contract MainnetController_Centrifuge_ClaimCancelDeposit_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_DEPOSIT(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);
    }

    function test_claimCentrifugeCancelDepositRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.claimCentrifugeCancelDepositRequest(address(jTreasuryVault));
    }

    function test_claimCentrifugeCancelDepositRequest_invalidVault() external {
        vm.expectRevert("CentrifugeFacet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.claimCentrifugeCancelDepositRequest(makeAddr("fake-vault"));
    }

    function test_claimCentrifugeCancelDepositRequest() external {
        deal(address(usdc), almProxy, 1_000_000e6);

        uint256 initialEscrowBal = usdc.balanceOf(ESCROW);

        assertEq(usdc.balanceOf(almProxy), 1_000_000e6);
        assertEq(usdc.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelDepositRequest(REQUEST_ID, almProxy), 0);

        vm.startPrank(RELAYER);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);
        mainnetController.cancelCentrifugeDepositRequest(address(jTreasuryVault));
        vm.stopPrank();

        assertEq(usdc.balanceOf(almProxy), 0);
        assertEq(usdc.balanceOf(ESCROW),   initialEscrowBal + 1_000_000e6);

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),         1_000_000e6);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy),   true);
        assertEq(jTreasuryVault.claimableCancelDepositRequest(REQUEST_ID, almProxy), 0);

        // Fulfill cancellation request
        vm.prank(ROOT);
        investmentManager.fulfillCancelDepositRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            1_000_000e6,
            1_000_000e6
        );

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelDepositRequest(REQUEST_ID, almProxy), 1_000_000e6);

        vm.prank(RELAYER);
        mainnetController.claimCentrifugeCancelDepositRequest(address(jTreasuryVault));

        assertEq(jTreasuryVault.pendingDepositRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelDepositRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelDepositRequest(REQUEST_ID, almProxy), 0);

        assertEq(usdc.balanceOf(almProxy), 1_000_000e6);
        assertEq(usdc.balanceOf(ESCROW),   initialEscrowBal);
    }

}

contract MainnetController_Centrifuge_RequestRedeemERC7540_Tests is Centrifuge_TestBase {

    bytes32 internal key;

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        key = makeAddressKey(
            mainnetController.LIMIT_7540_REDEEM(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);
    }

    function test_requestRedeemERC7540_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), 1_000_000e6);
    }

    function test_requestRedeemERC7540_zeroMaxAmount() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 0, 0);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), 1_000_000e6);
    }

    function test_requestRedeemERC7540_rateLimitsBoundary() external {
        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, 1_000_000e6);

        uint256 overBoundaryShares = jTreasuryVault.convertToShares(1_000_000e6 + 3);
        uint256 atBoundaryShares   = jTreasuryVault.convertToShares(1_000_000e6 + 1);

        assertEq(jTreasuryVault.convertToAssets(overBoundaryShares), 1_000_000e6 + 2);
        assertEq(jTreasuryVault.convertToAssets(atBoundaryShares),   1_000_000e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), overBoundaryShares);

        mainnetController.requestRedeemERC7540(address(jTreasuryVault), atBoundaryShares);
    }

    function test_requestRedeemERC7540() external {
        uint256 shares = jTreasuryVault.convertToShares(1_000_000e6);

        assertEq(shares, 948_558.832635e6);

        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, shares);

        assertEq(rateLimits.getCurrentRateLimit(key), 1_000_000e6);

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(almProxy), shares);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy), 0);

        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), shares);

        assertEq(rateLimits.getCurrentRateLimit(key), 1);  // Rounding

        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + shares);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy), shares);
    }

}

contract MainnetController_Centrifuge_ClaimRedeemERC7540_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_REDEEM(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 2_000_000e6, uint256(2_000_000e6) / 1 days);
    }

    function test_claimRedeemERC7540_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.claimRedeemERC7540(address(jTreasuryVault));
    }

    function test_claimRedeemERC7540_invalidVault() external {
        vm.expectRevert("ERC7540Facet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.claimRedeemERC7540(makeAddr("fake-vault"));
    }

    function test_claimRedeemERC7540_singleRequest() external {
        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, 1_000_000e6);

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(almProxy), 1_000_000e6);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);

        // Request JTRSY redemption
        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), 1_000_000e6);

        uint256 totalSupply = jTreasuryToken.totalSupply();

        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + 1_000_000e6);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   1_000_000e6);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);

        // Fulfill request at price 2.0
        deal(address(usdc), ESCROW, 2_000_000e6);

        vm.prank(ROOT);
        investmentManager.fulfillRedeemRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            2_000_000e6,
            1_000_000e6
        );

        assertEq(jTreasuryToken.totalSupply(),       totalSupply - 1_000_000e6);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(usdc.balanceOf(ESCROW),   2_000_000e6);
        assertEq(usdc.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 1_000_000e6);

        // Claim assets
        vm.prank(RELAYER);
        mainnetController.claimRedeemERC7540(address(jTreasuryVault));

        assertEq(usdc.balanceOf(ESCROW),   0);
        assertEq(usdc.balanceOf(almProxy), 2_000_000e6);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);
    }

    function test_claimRedeemERC7540_multipleRequests() external {
        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, 1_500_000e6);

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(almProxy), 1_500_000e6);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);

        // Request JTRSY redemption
        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), 1_000_000e6);

        uint256 totalSupply = jTreasuryToken.totalSupply();

        assertEq(jTreasuryToken.balanceOf(almProxy), 500_000e6);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + 1_000_000e6);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   1_000_000e6);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);

        // Request another JTRSY redemption
        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), 500_000e6);

        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + 1_500_000e6);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   1_500_000e6);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);

        // Fulfill both requests at price 2.0
        deal(address(usdc), ESCROW, 3_000_000e6);

        vm.prank(ROOT);
        investmentManager.fulfillRedeemRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            3_000_000e6,
            1_500_000e6
        );

        assertEq(jTreasuryToken.totalSupply(),       totalSupply - 1_500_000e6);
        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(usdc.balanceOf(ESCROW),   3_000_000e6);
        assertEq(usdc.balanceOf(almProxy), 0);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 1_500_000e6);

        // Claim assets
        vm.prank(RELAYER);
        mainnetController.claimRedeemERC7540(address(jTreasuryVault));

        assertEq(usdc.balanceOf(ESCROW),   0);
        assertEq(usdc.balanceOf(almProxy), 3_000_000e6);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),   0);
        assertEq(jTreasuryVault.claimableRedeemRequest(REQUEST_ID, almProxy), 0);
    }

}

contract MainnetController_Centrifuge_CancelRedeemRequest_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_REDEEM(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);
    }

    function test_cancelCentrifugeRedeemRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.cancelCentrifugeRedeemRequest(address(jTreasuryVault));
    }

    function test_cancelCentrifugeRedeemRequest_invalidVault() external {
        vm.expectRevert("CentrifugeFacet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.cancelCentrifugeRedeemRequest(makeAddr("fake-vault"));
    }

    function test_cancelCentrifugeRedeemRequest() external {
        uint256 shares = jTreasuryVault.convertToShares(1_000_000e6);

        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, shares);

        vm.prank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), shares);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),       shares);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy), false);

        vm.prank(RELAYER);
        mainnetController.cancelCentrifugeRedeemRequest(address(jTreasuryVault));

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),       shares);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy), true);
    }

}

contract MainnetController_Centrifuge_ClaimCancelRedeemRequest_Tests is Centrifuge_TestBase {

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), almProxy, type(uint64).max);

        bytes32 key = makeAddressKey(
            mainnetController.LIMIT_7540_REDEEM(),
            address(jTreasuryVault)
        );

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(key, 1_000_000e6, uint256(1_000_000e6) / 1 days);
    }

    function test_claimCentrifugeCancelRedeemRequest_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        mainnetController.claimCentrifugeCancelRedeemRequest(address(jTreasuryVault));
    }

    function test_claimCentrifugeCancelRedeemRequest_invalidVault() external {
        vm.expectRevert("CentrifugeFacet/invalid-action");
        vm.prank(RELAYER);
        mainnetController.claimCentrifugeCancelRedeemRequest(makeAddr("fake-vault"));
    }

    function test_claimCentrifugeCancelRedeemRequest() external {
        uint256 shares = jTreasuryVault.convertToShares(1_000_000e6);

        vm.prank(ROOT);
        jTreasuryToken.mint(almProxy, shares);

        uint256 initialEscrowBal = jTreasuryToken.balanceOf(ESCROW);

        assertEq(jTreasuryToken.balanceOf(almProxy), shares);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelRedeemRequest(REQUEST_ID, almProxy), 0);

        vm.startPrank(RELAYER);
        mainnetController.requestRedeemERC7540(address(jTreasuryVault), shares);
        mainnetController.cancelCentrifugeRedeemRequest(address(jTreasuryVault));
        vm.stopPrank();

        assertEq(jTreasuryToken.balanceOf(almProxy), 0);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal + shares);

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),         shares);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy),   true);
        assertEq(jTreasuryVault.claimableCancelRedeemRequest(REQUEST_ID, almProxy), 0);

        // Fulfill cancellation request
        vm.prank(ROOT);
        investmentManager.fulfillCancelRedeemRequest(
            JTREASURY_POOL_ID,
            JTREASURY_TRANCHE_ID,
            almProxy,
            USDC_ASSET_ID,
            uint128(shares)
        );

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelRedeemRequest(REQUEST_ID, almProxy), shares);

        vm.prank(RELAYER);
        mainnetController.claimCentrifugeCancelRedeemRequest(address(jTreasuryVault));

        assertEq(jTreasuryVault.pendingRedeemRequest(REQUEST_ID, almProxy),         0);
        assertEq(jTreasuryVault.pendingCancelRedeemRequest(REQUEST_ID, almProxy),   false);
        assertEq(jTreasuryVault.claimableCancelRedeemRequest(REQUEST_ID, almProxy), 0);

        assertEq(jTreasuryToken.balanceOf(almProxy), shares);
        assertEq(jTreasuryToken.balanceOf(ESCROW),   initialEscrowBal);
    }

}
