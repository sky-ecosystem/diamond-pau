// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import {
    OptionsBuilder
} from "../../lib/layerzero-v2/packages/layerzero-v2/evm/oapp/contracts/oapp/libs/OptionsBuilder.sol";

import { SafeERC20, IERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Ethereum as GroveEthereum } from "../../lib/grove-address-registry/src/Ethereum.sol";

import { makeAddressAddressKey, makeAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { AaveV3_TestBase }                   from "./Aave.t.sol";
import { Centrifuge_TestBase }               from "./Centrifuge.t.sol";
import { Curve_TestBase }                    from "./Curve.t.sol";
import { ERC4626_SUSDS_TestBase }            from "./ERC4626.t.sol";
import { MainnetController_Ethena_E2ETests } from "./Ethena.t.sol";
import { Farm_TestBase }                     from "./Farm.t.sol";
import { LayerZero_TestBase }                from "./LayerZero.t.sol";
import { Maple_TestBase }                    from "./Maple.t.sol";
import { Pendle_TestBase }                   from "./Pendle.t.sol";
import { WEETH_TestBase }                    from "./WEETH.t.sol";

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256 balance);

}

interface IAavePoolWithdraw {

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

}

interface ILayerZeroOFTLike {

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct SendParam {
        uint32  dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes   extraOptions;
        bytes   composeMsg;
        bytes   oftCmd;
    }

    function quoteSend(SendParam calldata sendParam, bool payInLzToken)
        external
        view
        returns (MessagingFee memory msgFee);

}

contract MainnetController_Aave_Attack_Tests is AaveV3_TestBase {

    function test_attack_assetChanged_depositAave() external {
        bytes32 aaveDepositKey = mainnetController.getAaveDepositRateLimitKey(ATOKEN_USDS, POOL, Ethereum.USDS);

        assertEq(rateLimits.getCurrentRateLimit(aaveDepositKey), 25_000_000e18);

        // Deposit succeeds with the original underlying (USDS).
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        vm.prank(allocator);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(aaveDepositKey), 24_000_000e18);

        // Attack: mock UNDERLYING_ASSET_ADDRESS() to return a different address
        address changedUnderlying = makeAddr("changed-underlying");
        vm.mockCall(
            ATOKEN_USDS,
            abi.encodeWithSignature("UNDERLYING_ASSET_ADDRESS()"),
            abi.encode(changedUnderlying)
        );

        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        // Cannot deposit with the changed asset
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

}

contract MainnetController_Curve_Attack_Tests is Curve_TestBase {

    using SafeERC20 for IERC20;

    function test_attack_coinsChanged_swapCurve() external {
        bytes32 curveSwapUSDTKey = mainnetController.getCurveSwapRateLimitKey(CURVE_POOL, Ethereum.USDT);

        assertEq(rateLimits.getCurrentRateLimit(curveSwapUSDTKey), 1_000_000e6);

        _addLiquidity();

        // Swap succeeds with the original coins() response (USDT at index 1).
        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        vm.prank(allocator);
        mainnetController.swapCurve(CURVE_POOL, 1, 0, 1_000_000e6, 998_000e6);

        assertEq(rateLimits.getCurrentRateLimit(curveSwapUSDTKey), 0);

        // Attack: mock coins(1) to return a different token.
        vm.mockCall(
            CURVE_POOL,
            abi.encodeWithSignature("coins(uint256)", 1),
            abi.encode(Ethereum.DAI)
        );

        deal(Ethereum.USDT, address(almProxy), 1);

        // Cannot swap with changed coins() token key.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.swapCurve(CURVE_POOL, 1, 0, 1, type(uint256).max);
    }

    function test_attack_coinsChanged_addLiquidityCurve() external {
        assertEq(rateLimits.getCurrentRateLimit(curveAggregateDepositKey), 2_000_000e18);

        // Deposit succeeds with the original coins() response.
        _addLiquidity();
        assertEq(rateLimits.getCurrentRateLimit(curveAggregateDepositKey), 0);

        // Recharge aggregate deposit limit for the second call.
        skip(2 days);

        assertEq(rateLimits.getCurrentRateLimit(curveAggregateDepositKey), 2_000_000e18);

        // Attack: mock coins() to return a different token address.
        vm.mockCall(
            CURVE_POOL,
            abi.encodeWithSignature("coins(uint256)", 0),
            abi.encode(Ethereum.DAI)
        );
        vm.mockCall(
            CURVE_POOL,
            abi.encodeWithSignature("coins(uint256)", 1),
            abi.encode(Ethereum.DAI)
        );

        uint256 usdcAmount = 1_000_000e6;
        uint256 usdtAmount = 1_000_000e6;

        deal(address(usdc), address(almProxy), usdcAmount);
        deal(address(usdt), address(almProxy), usdtAmount);

        vm.startPrank(address(almProxy));
        IERC20Like(address(usdc)).approve(CURVE_POOL, usdcAmount);
        IERC20(address(usdt)).safeIncreaseAllowance(CURVE_POOL, usdtAmount);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = usdtAmount;

        uint256 minLpAmount = (usdcAmount + usdtAmount) * 1e12 * 98/100;

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.addLiquidityCurve(CURVE_POOL, amounts, minLpAmount);
    }

}

contract MainnetController_Centrifuge_Attack_Tests is Centrifuge_TestBase {

    bytes32 depositKey;

    function setUp() public override {
        super.setUp();

        vm.prank(ROOT);
        restrictionManager.updateMember(address(jTreasuryToken), address(almProxy), type(uint64).max);

        depositKey       = mainnetController.getERC7540RequestDepositRateLimitKey(address(jTreasuryVault), Ethereum.USDC);

        vm.prank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 2_000_000e6, uint256(2_000_000e6) / 1 days);
    }

    function test_attack_assetChanged_requestDepositERC7540() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 2_000_000e6);

        // Request succeeds with original underlying (USDC).
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);

        vm.prank(allocator);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 1_000_000e6);

        // Attack: mock asset() to return a different address.
        address changedAsset = Ethereum.DAI;
        vm.mockCall(
            address(jTreasuryVault),
            abi.encodeWithSignature("asset()"),
            abi.encode(changedAsset)
        );

        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);

        // Cannot request another deposit with the changed asset.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.requestDepositERC7540(address(jTreasuryVault), 1_000_000e6);
    }

}

contract MainnetController_ERC4626_Attack_Tests is ERC4626_SUSDS_TestBase {

    function test_attack_assetChanged_depositERC4626() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 5_000_000e18);

        // Deposit succeeds with the original underlying (USDS).
        vm.startPrank(allocator);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.depositERC4626(address(susds), 1_000_000e18, 0);
        vm.stopPrank();

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 4_000_000e18);

        // Attack: mock asset() to return a different address
        address changedAsset = Ethereum.DAI;
        vm.mockCall(
            address(susds),
            abi.encodeWithSignature("asset()"),
            abi.encode(changedAsset)
        );

        vm.prank(allocator);
        mainnetController.mintUSDS(1_000_000e18);

        // Cannot deposit with the changed asset
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.depositERC4626(address(susds), 1_000_000e18, 0);
    }

}

contract MainnetController_Ethena_Attack_Tests is MainnetController_Ethena_E2ETests {

    function test_attack_compromisedAllocator_lockingFundsInEthenaSilo() external {
        deal(address(susde), address(almProxy), 1_000_000e18);

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        vm.prank(allocator);
        mainnetController.cooldownAssetsSUSDe(1_000_000e18);

        skip(7 days);

        // Allocator is now compromised and wants to lock funds in the silo
        vm.prank(allocator);
        mainnetController.cooldownAssetsSUSDe(1);

        // Real allocator cannot withdraw when they want to
        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        vm.prank(allocator);
        mainnetController.unstakeSUSDe();

        // Frezer can remove the compromised allocator and fallback to the governance allocator
        vm.prank(freezer);
        accessControls.revokeRole(ALLOCATOR_ROLE, allocator);

        skip(7 days);

        // Compromised allocator cannot perform attack anymore
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            allocator,
            ALLOCATOR_ROLE
        ));
        vm.prank(allocator);
        mainnetController.cooldownAssetsSUSDe(1);

        // Funds have been locked in the silo this whole time
        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),              startingSiloBalance + 1_000_000e18 + 1);  // 1 wei deposit as well

        // Backstop allocator can unstake the funds
        vm.prank(backstopAllocator);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 + 1);
        assertEq(usde.balanceOf(silo),              startingSiloBalance);
    }

}

contract MainnetController_Farm_Attack_Tests is Farm_TestBase {

    bytes32 depositKey;

    function setUp() public override {
        super.setUp();

        depositKey = mainnetController.getFarmDepositRateLimitKey(FARM, Ethereum.USDS);
    }

    function test_attack_stakingTokenChanged_depositToFarm() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 10_000_000e18);

        // Deposit succeeds with the original staking token (USDS).
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        vm.prank(allocator);
        mainnetController.depositToFarm(FARM, 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 9_000_000e18);

        // Attack: mock stakingToken() to return a different address.
        address changedStakingToken = Ethereum.DAI;
        vm.mockCall(
            FARM,
            abi.encodeWithSignature("stakingToken()"),
            abi.encode(changedStakingToken)
        );

        // Cannot deposit with changed staking token key.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.depositToFarm(FARM, 1);
    }

}

contract MainnetController_LayerZero_Attack_Tests is LayerZero_TestBase {

    using OptionsBuilder for bytes;

    function setUp() public override {
        super.setUp();

        vm.startPrank(SPARK_PROXY);
        rateLimits.setRateLimitData(key, 10_000_000e6, 0);
        mainnetController.setLayerZeroRecipient(DESTINATION_ENDPOINT_ID, target);
        vm.stopPrank();
    }

    function test_attack_tokenChanged_transferTokenLayerZero() external {
        assertEq(rateLimits.getCurrentRateLimit(key), 10_000_000e6);

        deal(Ethereum.USDT, address(almProxy), 1_000_000e6);

        deal(allocator, 1 ether);

        ILayerZeroOFTLike.SendParam memory sendParams = ILayerZeroOFTLike.SendParam({
            dstEid       : DESTINATION_ENDPOINT_ID,
            to           : target,
            amountLD     : 1_000_000e6,
            minAmountLD  : 1_000_000e6,
            extraOptions : OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0),
            composeMsg   : "",
            oftCmd       : ""
        });

        ILayerZeroOFTLike.MessagingFee memory fee = ILayerZeroOFTLike(USDT_OFT).quoteSend(sendParams, false);

        // Transfer succeeds with original token() response (USDT).
        vm.prank(allocator);
        mainnetController.transferTokenLayerZero{value: fee.nativeFee}(USDT_OFT, 1_000_000e6, DESTINATION_ENDPOINT_ID);

        assertEq(rateLimits.getCurrentRateLimit(key), 9_000_000e6);

        // Attack: mock token() to return a different asset.
        vm.mockCall(USDT_OFT, abi.encodeWithSignature("token()"), abi.encode(Ethereum.DAI));

        // Cannot transfer with changed token key.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.transferTokenLayerZero{value: fee.nativeFee}(USDT_OFT, 1, DESTINATION_ENDPOINT_ID);
    }

}

contract MainnetController_Maple_Attack_Tests is Maple_TestBase {

    function test_attack_compromisedAllocator_delayRequestMapleRedemption() external {
        deal(address(usdc), address(almProxy), 1_000_000e6);

        vm.prank(allocator);
        mainnetController.depositERC4626(address(SYRUP), 1_000_000e6, 0);

        // Malicious allocator delays the request for redemption for 1m
        // because new requests can't be fulfilled until the previous is fulfilled or cancelled
        vm.prank(allocator);
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Cannot process request
        vm.prank(allocator);
        vm.expectRevert("WM:AS:IN_QUEUE");
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);

        // Frezer can remove the compromised allocator and fallback to the governance allocator
        vm.prank(freezer);
        accessControls.revokeRole(ALLOCATOR_ROLE, allocator);

        // Compromised allocator cannot perform attack anymore
        vm.prank(allocator);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            allocator,
            ALLOCATOR_ROLE
        ));
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Governance allocator can cancel and submit the real request
        vm.startPrank(backstopAllocator);
        mainnetController.cancelMapleRedemption(address(SYRUP), 1);
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);
        vm.stopPrank();
    }

}

contract MainnetController_Pendle_Attack_Tests is Pendle_TestBase {

    function test_attack_readTokensChanged_redeemPendlePT() external {
        (address sy, address pt, address yt) = pendleMarket.readTokens();

        // Redeem succeeds with the original market token.
        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(address(almProxy), 1_000_000e18);

        vm.warp(pendleMarket.expiry());

        uint256 beforeLimit = rateLimits.getCurrentRateLimit(redeemKey);

        vm.prank(allocator);
        mainnetController.redeemPendlePT(address(pendleMarket), 500_000e18, 1);

        assertLt(rateLimits.getCurrentRateLimit(redeemKey), beforeLimit);

        vm.prank(PT_WHALE);
        IERC20Like(pt).transfer(address(almProxy), 500_000e18);

        // Attack: market implementation changes readTokens() to return a different PT.
        vm.mockCall(
            address(pendleMarket),
            abi.encodeWithSignature("readTokens()"),
            abi.encode(sy, Ethereum.DAI, yt)
        );

        vm.prank(address(almProxy));
        IERC20Like(pt).approve(GroveEthereum.PENDLE_ROUTER, type(uint256).max);

        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.redeemPendlePT(address(pendleMarket), 500_000e18, 1);
    }

}

contract MainnetController_WEETH_Attack_Tests is WEETH_TestBase {

    bytes32 depositKey;

    function setUp() public override {
        super.setUp();

        depositKey = mainnetController.getWEETHDepositRateLimitKey(address(eeth), address(liquidityPool));

        vm.startPrank(Ethereum.SPARK_PROXY);
        rateLimits.setRateLimitData(depositKey, 1_000e18, uint256(1_000e18) / 1 days);
        vm.stopPrank();
    }

    function test_attack_eETHChanged_depositToWeETH() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 1_000e18);

        // Deposit succeeds with the original eETH address.
        deal(Ethereum.WETH, address(almProxy), 1_000e18);

        vm.startPrank(allocator);
        mainnetController.depositToWeETH(1_000e18, _getMinSharesOut(1_000e18));
        vm.stopPrank();

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 0);

        // Attack: mutable dependency changes eETH address.
        vm.mockCall(
            Ethereum.WEETH,
            abi.encodeWithSignature("eETH()"),
            abi.encode(Ethereum.DAI)
        );
        vm.mockCall(
            Ethereum.DAI,
            abi.encodeWithSignature("liquidityPool()"),
            abi.encode(address(liquidityPool))
        );

        // Cannot deposit with the changed eETH address.
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(allocator);
        mainnetController.depositToWeETH(1, 0);
    }

}
