// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { makeAddressAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import { AaveV3_TestBase }                   from "./Aave.t.sol";
import { ERC4626_SUSDS_TestBase }            from "./ERC4626.t.sol";
import { MainnetController_Ethena_E2ETests } from "./Ethena.t.sol";
import { Maple_TestBase }                    from "./Maple.t.sol";

contract MainnetController_Ethena_Attack_Tests is MainnetController_Ethena_E2ETests {

    function test_attack_compromisedRelayer_lockingFundsInEthenaSilo() external {
        deal(address(susde), address(almProxy), 1_000_000e18);

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(1_000_000e18);

        skip(7 days);

        // Relayer is now compromised and wants to lock funds in the silo
        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(1);

        // Real relayer cannot withdraw when they want to
        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        vm.prank(relayer);
        mainnetController.unstakeSUSDe();

        // Frezer can remove the compromised relayer and fallback to the governance relayer
        vm.prank(freezer);
        accessControls.removeRelayer(relayer);

        skip(7 days);

        // Compromised relayer cannot perform attack anymore
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            relayer,
            RELAYER_ROLE
        ));
        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(1);

        // Funds have been locked in the silo this whole time
        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),              startingSiloBalance + 1_000_000e18 + 1);  // 1 wei deposit as well

        // Backstop relayer can unstake the funds
        vm.prank(backstopRelayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 + 1);
        assertEq(usde.balanceOf(silo),              startingSiloBalance);
    }

}

contract MainnetController_Maple_Attack_Tests is Maple_TestBase {

    function test_attack_compromisedRelayer_delayRequestMapleRedemption() external {
        deal(address(usdc), address(almProxy), 1_000_000e6);

        vm.prank(relayer);
        mainnetController.depositERC4626(address(SYRUP), 1_000_000e6, 0);

        // Malicious relayer delays the request for redemption for 1m
        // because new requests can't be fulfilled until the previous is fulfilled or cancelled
        vm.prank(relayer);
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Cannot process request
        vm.prank(relayer);
        vm.expectRevert("WM:AS:IN_QUEUE");
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);

        // Frezer can remove the compromised relayer and fallback to the governance relayer
        vm.prank(freezer);
        accessControls.removeRelayer(relayer);

        // Compromised relayer cannot perform attack anymore
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            relayer,
            RELAYER_ROLE
        ));
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Governance relayer can cancel and submit the real request
        vm.startPrank(backstopRelayer);
        mainnetController.cancelMapleRedemption(address(SYRUP), 1);
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);
        vm.stopPrank();
    }

}

contract MainnetController_ERC4626_Attack_Tests is ERC4626_SUSDS_TestBase {

    function test_attack_assetChanged_depositERC4626() external {
        assertEq(rateLimits.getCurrentRateLimit(depositKey), 5_000_000e18);

        // Deposit succeeds with the original underlying (USDS).
        vm.startPrank(relayer);
        mainnetController.mintUSDS(1_000_000e18);
        mainnetController.depositERC4626(address(susds), 1_000_000e18, 0);
        vm.stopPrank();

        assertEq(rateLimits.getCurrentRateLimit(depositKey), 4_000_000e18);

        // Attack: mock asset() to return a different address
        address changedAsset = makeAddr("changed-asset");
        vm.mockCall(
            address(susds),
            abi.encodeWithSignature("asset()"),
            abi.encode(changedAsset)
        );

        vm.prank(relayer);
        mainnetController.mintUSDS(1_000_000e18);

        // Cannot deposit with the changed asset
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(relayer);
        mainnetController.depositERC4626(address(susds), 1_000_000e18, 0);
    }

}

contract MainnetController_Aave_Attack_Tests is AaveV3_TestBase {

    function test_attack_assetChanged_depositAave() external {
        bytes32 aaveDepositKey = makeAddressAddressKey(
            mainnetController.LIMIT_AAVE_DEPOSIT(),
            Ethereum.USDS,
            ATOKEN_USDS
        );

        assertEq(rateLimits.getCurrentRateLimit(aaveDepositKey), 25_000_000e18);

        // Deposit succeeds with the original underlying (USDS).
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        vm.prank(relayer);
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
        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

}
