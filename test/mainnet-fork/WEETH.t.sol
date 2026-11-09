// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ERC1967Proxy }    from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IWEETHFacet }  from "../../src/facets/weeth/IWEETHFacet.sol";
import { WEETHModule } from "../../src/facets/weeth/WEETHModule.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface ILiquidityPoolLike {

    function addEthAmountLockedForWithdrawal(uint128 amount) external;

    function amountForShare(uint256 shareAmount) external view returns (uint256);

    function sharesForAmount(uint256 amount) external view returns (uint256);

    function withdrawRequestNFT() external view returns (address);

}

interface IWithdrawRequestNFTLike {

    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool   isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 requestId) external;

    function finalizeRequests(uint256 requestId) external;


    function getClaimableAmount(uint256 requestId) external view returns (uint256);

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function isFinalized(uint256 requestId) external view returns (bool);

    function isValid(uint256 requestId) external view returns (bool);

    function invalidateRequest(uint256 requestId) external;

    function nextRequestId() external view returns (uint32);

    function ownerOf(uint256 requestId) external view returns (address);

    function transferFrom(address from, address to, uint256 requestId) external;

}

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

}

interface IWEETHLike is IERC20Like {

    function eETH() external view returns (address);

    function getEETHByWeETH(uint256 weethAmount) external view returns (uint256);

}

interface IEETHLike is IERC20Like {

    function liquidityPool() external view returns (address);

}

abstract contract WEETH_TestBase is ForkTestBase {

    address internal constant ETHERFI_ADMIN    = 0x0EF8fa4760Db8f5Cd4d993f3e3416f30f942D705;
    address internal constant ETHERFI_GUARDIAN = 0x9AF1298993DC1f397973C62A5D47a284CF76844D;

    IERC20Like internal constant WETH  = IERC20Like(Ethereum.WETH);
    IWEETHLike internal constant WEETH = IWEETHLike(Ethereum.WEETH);

    IEETHLike          internal eeth;
    ILiquidityPoolLike internal liquidityPool;

    address internal weethModule;

    function setUp() public override virtual {
        super.setUp();

        eeth          = IEETHLike(WEETH.eETH());
        liquidityPool = ILiquidityPoolLike(eeth.liquidityPool());

        weethModule = address(
            new ERC1967Proxy(
                address(new WEETHModule(Ethereum.WEETH, Ethereum.WETH)),
                abi.encodeCall(
                    WEETHModule.initialize,
                    (Ethereum.SPARK_PROXY, address(almProxy))
                )
            )
        );
    }

    function _getBlock() internal pure override returns (uint256) {
        return 25600000; //  July 23, 2026
    }

    // Finalizes the request and locks its ETH in the WithdrawRequestNFT.
    function _finalizeRequest(uint256 requestId) internal {
        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        vm.startPrank(ETHERFI_ADMIN);

        withdrawRequestNFT.finalizeRequests(requestId);

        liquidityPool.addEthAmountLockedForWithdrawal(withdrawRequestNFT.getRequest(requestId).amountOfEEth);

        vm.stopPrank();
    }

    function _getMinSharesOut(uint256 amount) internal view returns (uint256) {
        return liquidityPool.sharesForAmount(amount) - 1;
    }

    function _getMinEETHShares(uint256 amount) internal view returns (uint256) {
        return liquidityPool.sharesForAmount(amount);
    }

}

contract MainnetController_WEETH_Deposit_Tests is WEETH_TestBase {

    bytes32 internal depositKey;

    function setUp() public override {
        super.setUp();

        depositKey = mainnetController.weeth_getDepositRateLimitKey(address(eeth), address(liquidityPool));
    }

    function test_depositToWEETH_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.weeth_deposit(1e18, 0);
    }

    function test_depositToWEETH_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.weeth_deposit(1e18, 0);
    }

    function test_depositToWEETH_zeroMaxAmount() external {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.weeth_deposit(1e18, 0);
    }

    function test_depositToWEETH_rateLimitsBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 1_000e18, uint256(1_000e18) / 1 days);

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18 + 1, 0);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, 0);
    }

    function test_depositToWEETH_slippageTooHighBoundary() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 1_000e18, uint256(1_000e18) / 1 days);

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.expectRevert("WEETHFacet/slippage-too-high");
        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut + 1);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);
    }

    function test_depositToWEETH() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 1_000e18, uint256(1_000e18) / 1 days);

        deal(address(almProxy), 1_000e18);

        deal(Ethereum.WETH, address(almProxy), 2_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 1_000e18);

        uint256 initialLiquidityPoolBalance = address(liquidityPool).balance;

        assertEq(address(almProxy).balance,          1_000e18);
        assertEq(WETH.balanceOf(address(almProxy)),  2_000e18);
        assertEq(eeth.balanceOf(address(almProxy)),  0);
        assertEq(WEETH.balanceOf(address(almProxy)), 0);
        assertEq(address(liquidityPool).balance,     initialLiquidityPoolBalance);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit IWEETHFacet.WEETHDeposit(
            1_000e18,
            1_000e18 - 1, // Rounding
            909.162763198571016822e18
        );

        vm.prank(allocator);
        uint256 shares = mainnetController.weeth_deposit(1_000e18, minSharesOut);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 0);

        assertEq(eeth.allowance(address(almProxy), Ethereum.WEETH), 0);

        assertEq(shares, WEETH.balanceOf(address(almProxy)));

        assertEq(address(almProxy).balance,          1_000e18);
        assertEq(WETH.balanceOf(address(almProxy)),  1_000e18);
        assertEq(WEETH.balanceOf(address(almProxy)), 909.162763198571016822e18);
        assertEq(address(liquidityPool).balance,     initialLiquidityPoolBalance + 1_000e18);

        assertApproxEqAbs(eeth.balanceOf(address(almProxy)),                                0,        1);
        assertApproxEqAbs(liquidityPool.amountForShare(WEETH.balanceOf(address(almProxy))), 1_000e18, 2);
    }

}

contract MainnetController_WEETH_RequestWithdraw_Tests is WEETH_TestBase {

    bytes32 internal depositKey;
    bytes32 internal requestWithdrawKey;

    function setUp() public override {
        super.setUp();

        depositKey = mainnetController.weeth_getDepositRateLimitKey(address(eeth), address(liquidityPool));

        requestWithdrawKey = mainnetController.weeth_getRequestWithdrawRateLimitKey(weethModule, address(eeth), address(liquidityPool));
    }

    function test_requestWithdrawFromWEETH_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.weeth_requestWithdraw(weethModule, 1e18, 0);
    }

    function test_requestWithdrawFromWEETH_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.weeth_requestWithdraw(weethModule, 1e18, 0);
    }

    function test_requestWithdrawFromWEETH_zeroMaxAmount() external {
        deal(Ethereum.WEETH, address(almProxy), 1e18);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.weeth_requestWithdraw(weethModule, 1e18, 0);
    }

    function test_requestWithdrawFromWEETH_rateLimitsBoundary() external {
        uint256 eethLimit = WEETH.getEETHByWeETH(500e18 - 1); // Rounding error

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(requestWithdrawKey, eethLimit, eethLimit / 1 days);

        deal(Ethereum.WEETH, address(almProxy), 500e18 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.weeth_requestWithdraw(weethModule, 500e18 + 1, 0);

        vm.prank(allocator);
        mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);
    }

    function test_requestWithdrawFromWEETH_slippageTooHighBoundary() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        uint256 expectedEETHBalance = WEETH.getEETHByWeETH(500e18 - 1); // Rounding error

        uint256 minEETHShares = _getMinEETHShares(expectedEETHBalance);

        vm.expectRevert("WEETHFacet/slippage-too-high");
        vm.prank(allocator);
        mainnetController.weeth_requestWithdraw(
            weethModule,
            500e18,
            minEETHShares + 1
        );

        vm.prank(allocator);
        mainnetController.weeth_requestWithdraw(
            weethModule,
            500e18,
            minEETHShares
        );
    }

    function test_requestWithdrawFromWEETH() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        uint256 initialWEETHBalance = WEETH.balanceOf(address(almProxy));

        assertEq(initialWEETHBalance,                                       909.162763198571016822e18);
        assertEq(eeth.allowance(address(almProxy), address(liquidityPool)), 0);

        uint256 expectedEETHBalance = WEETH.getEETHByWeETH(500e18 - 1); // Rounding error

        uint256 minEETHShares = _getMinEETHShares(expectedEETHBalance);

        vm.record();

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        uint32 nextRequestId = withdrawRequestNFT.nextRequestId();

        vm.expectEmit(address(mainnetController));
        emit IWEETHFacet.WEETHRequestWithdraw(
            weethModule,
            nextRequestId,
            expectedEETHBalance,
            500e18
        );

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(
            weethModule,
            500e18,
            minEETHShares
        );

        _assertReentrancyGuardWrittenToTwice();

        assertEq(WEETH.balanceOf(address(almProxy)),                        initialWEETHBalance - 500e18);
        assertEq(eeth.allowance(address(almProxy), address(liquidityPool)), 0);

        assertEq(expectedEETHBalance, 549.956531700577988025e18);

        assertEq(
            rateLimits.getCurrentRateLimit(requestWithdrawKey),
            1_000e18 - expectedEETHBalance
        );

        assertEq(withdrawRequestNFT.isValid(requestId),     true);
        assertEq(withdrawRequestNFT.isFinalized(requestId), false);

        _finalizeRequest(requestId);

        assertEq(withdrawRequestNFT.isFinalized(requestId),        true);
        assertEq(withdrawRequestNFT.getClaimableAmount(requestId), expectedEETHBalance);

        assertEq(withdrawRequestNFT.ownerOf(requestId), weethModule);
    }

}

contract MainnetController_WEETH_ClaimWithdrawal_Tests is WEETH_TestBase {

    bytes32 internal depositKey;
    bytes32 internal requestWithdrawKey;
    bytes32 internal claimWithdrawKey;

    function setUp() public override {
        super.setUp();

        depositKey = mainnetController.weeth_getDepositRateLimitKey(address(eeth), address(liquidityPool));

        requestWithdrawKey = mainnetController.weeth_getRequestWithdrawRateLimitKey(weethModule, address(eeth), address(liquidityPool));

        claimWithdrawKey = mainnetController.weeth_getClaimWithdrawRateLimitKey(weethModule);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(claimWithdrawKey, type(uint256).max, 0);
    }

    function test_claimWithdrawalFromWEETH_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.weeth_claimWithdrawal(weethModule, 1);
    }

    function test_claimWithdrawalFromWEETH_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.weeth_claimWithdrawal(weethModule, 1);
    }

    function test_claimWithdrawalFromWEETH_invalidAction() external {
        vm.expectRevert("WEETHFacet/invalid-action");
        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(makeAddr("invalid-weethModule"), 1);
    }

    function test_claimWithdrawalFromWEETH_failsOnClaimingTwice() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        _finalizeRequest(requestId);

        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(weethModule, requestId);

        // Cannot claim withdrawal again: the request was deleted and the module holds no ETH.
        vm.expectRevert("WEETHModule/nothing-to-claim");
        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(weethModule, requestId);
    }

    function test_claimWithdrawalFromWEETH_notRequestOwner() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        _finalizeRequest(requestId);

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        // The request still exists but is no longer owned by the module.
        vm.prank(weethModule);
        withdrawRequestNFT.transferFrom(weethModule, makeAddr("otherOwner"), requestId);

        vm.expectRevert("WEETHModule/not-request-owner");
        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(weethModule, requestId);
    }

    function test_claimWithdrawalFromWEETH_invalidRequest() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        vm.prank(ETHERFI_GUARDIAN);
        IWithdrawRequestNFTLike(withdrawRequestNFT).invalidateRequest(requestId);

        vm.expectRevert("WEETHModule/invalid-request-id");
        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(weethModule, requestId);

        assertEq(WEETH.balanceOf(address(almProxy)), 409.162763198571016822e18);
    }

    function test_claimWithdrawalFromWEETH_requestNotFinalized() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        assertEq(withdrawRequestNFT.isValid(requestId),     true);
        assertEq(withdrawRequestNFT.isFinalized(requestId), false);

        vm.expectRevert("WEETHModule/request-not-finalized");
        vm.prank(allocator);
        mainnetController.weeth_claimWithdrawal(weethModule, requestId);
    }

    function test_claimWithdrawalFromWEETH() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(address(almProxy), 1_000e18);

        deal(Ethereum.WETH, address(almProxy), 2_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        _finalizeRequest(requestId);

        uint256 eethAmount = 549.956531700577988025e18;

        assertEq(withdrawRequestNFT.getClaimableAmount(requestId), eethAmount);

        assertEq(address(almProxy).balance,         1_000e18);
        assertEq(WETH.balanceOf(address(almProxy)), 1_000e18);
        assertEq(weethModule.balance,               0);
        assertEq(WETH.balanceOf(weethModule),       0);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit IWEETHFacet.WEETHClaimWithdrawal(weethModule, requestId, eethAmount);

        vm.prank(allocator);
        uint256 wethReceived = mainnetController.weeth_claimWithdrawal(weethModule, requestId);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(address(almProxy).balance,         1_000e18);
        assertEq(WETH.balanceOf(address(almProxy)), 1_000e18 + eethAmount);
        assertEq(weethModule.balance,               0);
        assertEq(WETH.balanceOf(weethModule),       0);
        assertEq(wethReceived,                      eethAmount);
    }

    function test_claimWithdrawalFromWEETH_settledByThirdParty() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey,         1_000e18, uint256(1_000e18) / 1 days);
        rateLimits.setRateLimitData(requestWithdrawKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();

        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        uint256 minSharesOut = _getMinSharesOut(1_000e18);

        vm.prank(allocator);
        mainnetController.weeth_deposit(1_000e18, minSharesOut);

        vm.prank(allocator);
        uint256 requestId = mainnetController.weeth_requestWithdraw(weethModule, 500e18, 0);

        IWithdrawRequestNFTLike withdrawRequestNFT = IWithdrawRequestNFTLike(liquidityPool.withdrawRequestNFT());

        _finalizeRequest(requestId);

        uint256 eethAmount = 549.956531700577988025e18;

        assertEq(withdrawRequestNFT.getClaimableAmount(requestId), eethAmount);

        assertEq(WETH.balanceOf(address(almProxy)), 0);
        assertEq(weethModule.balance,               0);

        // Any account can settle a finalized request, paying the ETH to the module (the NFT owner)
        // and deleting the request.
        vm.prank(makeAddr("thirdParty"));
        withdrawRequestNFT.claimWithdraw(requestId);

        assertEq(weethModule.balance,                                  eethAmount);
        assertEq(withdrawRequestNFT.getRequest(requestId).shareOfEEth, 0);

        vm.record();

        // The allocator's claim for the settled request sweeps the ETH instead of reverting.
        vm.expectEmit(address(mainnetController));
        emit IWEETHFacet.WEETHClaimWithdrawal(weethModule, requestId, eethAmount);

        vm.prank(allocator);
        uint256 wethReceived = mainnetController.weeth_claimWithdrawal(weethModule, requestId);

        _assertReentrancyGuardWrittenToTwice();

        assertEq(WETH.balanceOf(address(almProxy)), eethAmount);
        assertEq(weethModule.balance,               0);
        assertEq(WETH.balanceOf(weethModule),       0);
        assertEq(wethReceived,                      eethAmount);
    }

}
