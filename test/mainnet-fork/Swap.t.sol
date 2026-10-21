// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ERC20Mock }       from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { ISwapFacet } from "../../src/facets/swap/ISwapFacet.sol";

import { IAccessControls } from "../../src/interfaces/IAccessControls.sol";
import { IALMProxy }       from "../../src/interfaces/IALMProxy.sol";
import { IRateLimits }     from "../../src/interfaces/IRateLimits.sol";

import { MockTokenReturnFalse, MockTokenReturn64Bytes } from "../mocks/Mocks.sol";

import { IMainnetControllerFull } from "../interfaces/IMainnetControllerFull.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

}

// Mock ERC20 that keeps a fee on transferFrom, so the receiver gets less than requested.
contract MockTokenFeeOnTransferFrom is ERC20Mock {

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _transfer(from, to, value - 1);
        _burn(from, 1);
        return true;
    }

}

abstract contract Swap_TestBase is ForkTestBase {

    IERC20Like internal constant USDS = IERC20Like(Ethereum.USDS);
    IERC20Like internal constant USDT = IERC20Like(Ethereum.USDT);

    // Second PAU standing in for a Spark Savings vault PAU (same beacon, own stack).
    IAccessControls        internal savingsAccessControls;
    IALMProxy              internal savingsProxy;
    IMainnetControllerFull internal savingsController;
    IRateLimits            internal savingsRateLimits;

    bytes32 internal usdsToUsdtKey;  // SLL sends USDS, receives USDT from the savings PAU
    bytes32 internal usdtToUsdsKey;  // SLL sends USDT, receives USDS from the savings PAU

    bytes32 internal savingsUsdtToUsdsKey;  // Savings PAU sends USDT, receives USDS from the SLL

    function setUp() public virtual override {
        super.setUp();

        /*** Deploy the savings PAU ***/

        savingsRateLimits     = IRateLimits(factory.deployRateLimits(Ethereum.SPARK_PROXY));
        savingsAccessControls = IAccessControls(factory.deployAccessControls(Ethereum.SPARK_PROXY));
        savingsProxy          = IALMProxy(factory.deployALMProxy(Ethereum.SPARK_PROXY));

        savingsController = IMainnetControllerFull(
            payable(
                factory.deployController(
                    address(savingsAccessControls),
                    address(savingsProxy),
                    address(savingsRateLimits)
                )
            )
        );

        vm.startPrank(Ethereum.SPARK_PROXY);

        savingsProxy.grantRole(savingsProxy.CONTROLLER(),           address(savingsController));
        savingsRateLimits.grantRole(savingsRateLimits.CONTROLLER(), address(savingsController));

        savingsAccessControls.grantRole(ALLOCATOR_ROLE, allocator);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "SWAP_FACET";

        savingsController.updateIntegrations(integrationIds);

        /*** Configure par values on both PAUs ***/

        mainnetController.swap_setParValue(Ethereum.USDS, 1e18);
        mainnetController.swap_setParValue(Ethereum.USDT, 1e18);

        savingsController.swap_setParValue(Ethereum.USDS, 1e18);
        savingsController.swap_setParValue(Ethereum.USDT, 1e18);

        /*** Standing allowances: each PAU lets the other pull the asset it sells ***/

        mainnetController.swap_approve(Ethereum.USDS, address(savingsProxy), 10_000_000e18);
        savingsController.swap_approve(Ethereum.USDT, address(almProxy),     10_000_000e6);

        /*** Rate limits ***/

        usdsToUsdtKey = mainnetController.swap_getSwapRateLimitKey(
            Ethereum.USDS,
            Ethereum.USDT,
            address(savingsProxy)
        );

        usdtToUsdsKey = mainnetController.swap_getSwapRateLimitKey(
            Ethereum.USDT,
            Ethereum.USDS,
            address(savingsProxy)
        );

        savingsUsdtToUsdsKey = savingsController.swap_getSwapRateLimitKey(
            Ethereum.USDT,
            Ethereum.USDS,
            address(almProxy)
        );

        rateLimits.setRateLimitData(usdsToUsdtKey, 5_000_000e18, uint256(1_000_000e18) / 1 days);

        savingsRateLimits.setRateLimitData(
            savingsUsdtToUsdsKey,
            5_000_000e6,
            uint256(1_000_000e6) / 1 days
        );

        vm.stopPrank();

        /*** Fund both proxies ***/

        deal(Ethereum.USDS, address(almProxy),     5_000_000e18 + 1);
        deal(Ethereum.USDT, address(savingsProxy), 5_000_000e6 + 1);

        vm.label(address(savingsAccessControls), "SavingsAccessControls");
        vm.label(address(savingsController),     "SavingsController");
        vm.label(address(savingsProxy),          "SavingsProxy");
        vm.label(address(savingsRateLimits),     "SavingsRateLimits");
        vm.label(address(usdt),                  "usdt");
    }

    function _assertBalances(
        uint256 almProxyUsds,
        uint256 almProxyUsdt,
        uint256 savingsProxyUsds,
        uint256 savingsProxyUsdt
    )
        internal
        view
    {
        assertEq(USDS.balanceOf(address(almProxy)),     almProxyUsds);
        assertEq(USDT.balanceOf(address(almProxy)),     almProxyUsdt);
        assertEq(USDS.balanceOf(address(savingsProxy)), savingsProxyUsds);
        assertEq(USDT.balanceOf(address(savingsProxy)), savingsProxyUsdt);

        assertEq(USDS.balanceOf(address(mainnetController)), 0);
        assertEq(USDT.balanceOf(address(mainnetController)), 0);
        assertEq(USDS.balanceOf(address(savingsController)), 0);
        assertEq(USDT.balanceOf(address(savingsController)), 0);
    }

}

contract MainnetController_Swap_Swap_Tests is Swap_TestBase {

    function test_swap_reentrancy() external {
        _setControllerEntered();
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e18, 0);
    }

    function test_swap_notAllocator() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            ALLOCATOR_ROLE
        ));
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e18, 0);
    }

    function test_swap_sameAsset() external {
        vm.expectRevert("SwapFacet/same-asset");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDS, 1e18, 0);
    }

    function test_swap_zeroAmountIn() external {
        vm.expectRevert("SwapFacet/zero-amount-in");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 0, 0);
    }

    function test_swap_zeroMaxAmount() external {
        // Opposite direction is not configured on the SLL side.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDT, Ethereum.USDS, 1e6, 0);

        // Same assets, unknown counterparty.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swap_swap(makeAddr("other"), Ethereum.USDS, Ethereum.USDT, 1e18, 0);
    }

    function test_swap_rateLimitBoundary() external {
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(allocator);
        mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            5_000_000e18 + 1,
            0
        );

        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 5_000_000e18, 0);
    }

    function test_swap_parValueInNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(Ethereum.USDS, 0);

        vm.expectRevert("SwapFacet/par-value-in-not-set");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e18, 0);
    }

    function test_swap_parValueOutNotSet() external {
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(Ethereum.USDT, 0);

        vm.expectRevert("SwapFacet/par-value-out-not-set");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e18, 0);
    }

    function test_swap_zeroAmountOutBoundary() external {
        // 1e12 - 1 wei of USDS rounds down to zero USDT.
        vm.expectRevert("SwapFacet/zero-amount-out");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e12 - 1, 0);

        vm.prank(allocator);
        uint256 amountOut
            = mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1e12, 0);

        assertEq(amountOut, 1);
    }

    function test_swap_minAmountOutBoundary() external {
        vm.expectRevert("SwapFacet/min-amount-out-not-met");
        vm.prank(allocator);
        mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6 + 1
        );

        vm.prank(allocator);
        mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );
    }

    function test_swap_insufficientAllowance() external {
        vm.prank(Ethereum.SPARK_PROXY);
        savingsController.swap_approve(Ethereum.USDT, address(almProxy), 1_000_000e6 - 1);

        // USDT reverts without data on insufficient allowance.
        vm.expectRevert();
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1_000_000e18, 0);

        vm.prank(Ethereum.SPARK_PROXY);
        savingsController.swap_approve(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1_000_000e18, 0);

        assertEq(USDT.allowance(address(savingsProxy), address(almProxy)), 0);
    }

    function test_swap_transferFailedOnReturnFalse() external {
        address token = address(new MockTokenReturnFalse());

        bytes32 key = mainnetController.swap_getSwapRateLimitKey(token, Ethereum.USDT, address(savingsProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(token, 1e18);
        rateLimits.setRateLimitData(key, 1_000_000e18, 0);
        vm.stopPrank();

        deal(token, address(almProxy), 1_000_000e18);

        vm.expectRevert("SwapFacet/transfer-failed");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), token, Ethereum.USDT, 1_000_000e18, 0);
    }

    function test_swap_transferFailedOnNonStandardReturnData() external {
        address token = address(new MockTokenReturn64Bytes());

        bytes32 key = mainnetController.swap_getSwapRateLimitKey(token, Ethereum.USDT, address(savingsProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(token, 1e18);
        rateLimits.setRateLimitData(key, 1_000_000e18, 0);
        vm.stopPrank();

        vm.expectRevert("SwapFacet/transfer-failed");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), token, Ethereum.USDT, 1_000_000e18, 0);
    }

    function test_swap_transferFromFailedOnReturnFalse() external {
        address token = address(new MockTokenReturnFalse());

        bytes32 key = mainnetController.swap_getSwapRateLimitKey(Ethereum.USDS, token, address(savingsProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(token, 1e18);
        rateLimits.setRateLimitData(key, 1_000_000e18, 0);
        vm.stopPrank();

        deal(token, address(savingsProxy), 1_000_000e18);

        vm.prank(address(savingsProxy));
        MockTokenReturnFalse(token).approve(address(almProxy), 1_000_000e18);

        vm.expectRevert("SwapFacet/transferFrom-failed");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, token, 1_000_000e18, 0);
    }

    function test_swap_transferFromFailedOnNonStandardReturnData() external {
        address token = address(new MockTokenReturn64Bytes());

        bytes32 key = mainnetController.swap_getSwapRateLimitKey(Ethereum.USDS, token, address(savingsProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(token, 1e18);
        rateLimits.setRateLimitData(key, 1_000_000e18, 0);
        vm.stopPrank();

        vm.expectRevert("SwapFacet/transferFrom-failed");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, token, 1_000_000e18, 0);
    }

    function test_swap_amountOutMismatch() external {
        address token = address(new MockTokenFeeOnTransferFrom());

        bytes32 key = mainnetController.swap_getSwapRateLimitKey(Ethereum.USDS, token, address(savingsProxy));

        vm.startPrank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(token, 1e18);
        rateLimits.setRateLimitData(key, 1_000_000e18, 0);
        vm.stopPrank();

        deal(token, address(savingsProxy), 1_000_000e18);

        vm.prank(address(savingsProxy));
        MockTokenFeeOnTransferFrom(token).approve(address(almProxy), 1_000_000e18);

        vm.expectRevert("SwapFacet/amount-out-mismatch");
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, token, 1_000_000e18, 0);
    }

    function test_swap_decimalsSnapshot() external {
        // A change to decimals() after configuration does not change the pricing.
        vm.mockCall(
            Ethereum.USDT,
            abi.encodeWithSignature("decimals()"),
            abi.encode(uint8(18))
        );

        assertEq(
            mainnetController.swap_getAmountOut(Ethereum.USDS, Ethereum.USDT, 1_000_000e18),
            1_000_000e6
        );

        vm.prank(allocator);
        uint256 amountOut = mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        assertEq(amountOut, 1_000_000e6);

        vm.clearMockedCalls();
    }

    function test_swap() external {
        _assertBalances({
            almProxyUsds     : 5_000_000e18 + 1,
            almProxyUsdt     : 0,
            savingsProxyUsds : 0,
            savingsProxyUsdt : 5_000_000e6 + 1
        });

        assertEq(USDS.allowance(address(almProxy),     address(savingsProxy)), 10_000_000e18);
        assertEq(USDT.allowance(address(savingsProxy), address(almProxy)),     10_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 0);

        assertEq(savingsRateLimits.getCurrentRateLimit(savingsUsdtToUsdsKey), 5_000_000e6);

        vm.record();

        vm.expectEmit(address(mainnetController));
        emit ISwapFacet.SwapExecuted(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        vm.prank(allocator);
        uint256 amountOut = mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            1_000_000e18,
            1_000_000e6
        );

        _assertReentrancyGuardWrittenToTwice();

        assertEq(amountOut, 1_000_000e6);

        _assertBalances({
            almProxyUsds     : 4_000_000e18 + 1,
            almProxyUsdt     : 1_000_000e6,
            savingsProxyUsds : 1_000_000e18,
            savingsProxyUsdt : 4_000_000e6 + 1
        });

        // Pushed leg does not touch the SLL allowance; pulled leg consumes the savings allowance.
        assertEq(USDS.allowance(address(almProxy),     address(savingsProxy)), 10_000_000e18);
        assertEq(USDT.allowance(address(savingsProxy), address(almProxy)),     9_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 0);  // Unset, try-increase no-ops

        // The savings PAU's own limits are not consulted when the SLL executes.
        assertEq(savingsRateLimits.getCurrentRateLimit(savingsUsdtToUsdsKey), 5_000_000e6);
    }

    function test_swap_refillsOppositeRateLimit() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUsdsKey, 5_000_000e6, 0);
        savingsController.swap_approve(Ethereum.USDS, address(almProxy), 10_000_000e18);
        vm.stopPrank();

        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1_000_000e18, 0);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 4_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 5_000_000e6);

        _assertBalances({
            almProxyUsds     : 4_000_000e18 + 1,
            almProxyUsdt     : 1_000_000e6,
            savingsProxyUsds : 1_000_000e18,
            savingsProxyUsdt : 4_000_000e6 + 1
        });

        // Swap back: USDT leaves the SLL, USDS is pulled from the savings PAU.
        vm.expectEmit(address(mainnetController));
        emit ISwapFacet.SwapExecuted(
            address(savingsProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            400_000e6,
            400_000e18
        );

        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDT, Ethereum.USDS, 400_000e6, 0);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 4_400_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 4_600_000e6);

        _assertBalances({
            almProxyUsds     : 4_400_000e18 + 1,
            almProxyUsdt     : 600_000e6,
            savingsProxyUsds : 600_000e18,
            savingsProxyUsdt : 4_400_000e6 + 1
        });

        assertEq(USDS.allowance(address(savingsProxy), address(almProxy)), 9_600_000e18);
    }

    function test_swap_refillCappedAtMaxAmount() external {
        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(usdtToUsdsKey, 5_000_000e6, 0);
        savingsController.swap_approve(Ethereum.USDS, address(almProxy), 10_000_000e18);
        vm.stopPrank();

        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        // Refill of the untouched USDS -> USDT limit stays capped at its max amount.
        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDT, Ethereum.USDS, 1_000_000e6, 0);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 4_000_000e6);
    }

    function test_swap_unlimitedRateLimit() external {
        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setUnlimitedRateLimitData(usdsToUsdtKey);

        vm.prank(allocator);
        mainnetController.swap_swap(address(savingsProxy), Ethereum.USDS, Ethereum.USDT, 1_000_000e18, 0);

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), type(uint256).max);

        _assertBalances({
            almProxyUsds     : 4_000_000e18 + 1,
            almProxyUsdt     : 1_000_000e6,
            savingsProxyUsds : 1_000_000e18,
            savingsProxyUsdt : 4_000_000e6 + 1
        });
    }

    function test_swap_haircut() external {
        // Governance marks USDT down to 0.9 USDS on the executing PAU: one USDS buys 1.111111 USDT.
        vm.prank(Ethereum.SPARK_PROXY);
        mainnetController.swap_setParValue(Ethereum.USDT, 0.9e18);

        assertEq(
            mainnetController.swap_getAmountOut(Ethereum.USDS, Ethereum.USDT, 900_000e18),
            1_000_000e6
        );

        vm.expectEmit(address(mainnetController));
        emit ISwapFacet.SwapExecuted(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            900_000e18,
            1_000_000e6
        );

        vm.prank(allocator);
        uint256 amountOut = mainnetController.swap_swap(
            address(savingsProxy),
            Ethereum.USDS,
            Ethereum.USDT,
            900_000e18,
            1_000_000e6
        );

        assertEq(amountOut, 1_000_000e6);

        _assertBalances({
            almProxyUsds     : 4_100_000e18 + 1,
            almProxyUsdt     : 1_000_000e6,
            savingsProxyUsds : 900_000e18,
            savingsProxyUsdt : 4_000_000e6 + 1
        });

        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 4_100_000e18);
    }

    function test_swap_fromSavingsController() external {
        // The savings PAU sells USDT for USDS using its own controller, limits and the SLL allowance.
        vm.record();

        vm.expectEmit(address(savingsController));
        emit ISwapFacet.SwapExecuted(
            address(almProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            2_000_000e6,
            2_000_000e18
        );

        vm.prank(allocator);
        uint256 amountOut = savingsController.swap_swap(
            address(almProxy),
            Ethereum.USDT,
            Ethereum.USDS,
            2_000_000e6,
            2_000_000e18
        );

        _assertReentrancyGuardWrittenToTwice(address(savingsController));

        assertEq(amountOut, 2_000_000e18);

        _assertBalances({
            almProxyUsds     : 3_000_000e18 + 1,
            almProxyUsdt     : 2_000_000e6,
            savingsProxyUsds : 2_000_000e18,
            savingsProxyUsdt : 3_000_000e6 + 1
        });

        assertEq(USDS.allowance(address(almProxy),     address(savingsProxy)), 8_000_000e18);
        assertEq(USDT.allowance(address(savingsProxy), address(almProxy)),     10_000_000e6);

        assertEq(savingsRateLimits.getCurrentRateLimit(savingsUsdtToUsdsKey), 3_000_000e6);

        // The SLL's own limits are not consulted when the savings PAU executes.
        assertEq(rateLimits.getCurrentRateLimit(usdsToUsdtKey), 5_000_000e18);
        assertEq(rateLimits.getCurrentRateLimit(usdtToUsdsKey), 0);
    }

}
