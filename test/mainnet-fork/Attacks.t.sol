// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { MainnetController_Ethena_E2ETests } from "./Ethena.t.sol";
import { Maple_TestBase }                    from "./Maple.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

contract MainnetController_Ethena_Attack_Tests is MainnetController_Ethena_E2ETests {

    function test_attack_compromisedRelayer_lockingFundsInEthenaSilo() external {
        deal(address(susde), almProxy, 1_000_000e18);

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        vm.prank(RELAYER);
        mainnetController.cooldownAssetsSUSDe(1_000_000e18);

        skip(7 days);

        // Relayer is now compromised and wants to lock funds in the silo
        vm.prank(RELAYER);
        mainnetController.cooldownAssetsSUSDe(1);

        // Real relayer cannot withdraw when they want to
        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        vm.prank(RELAYER);
        mainnetController.unstakeSUSDe();

        // Freezer can remove the compromised relayer and fallback to the governance relayer
        vm.prank(FREEZER);
        accessControls.removeRelayer(RELAYER);

        skip(7 days);

        // Compromised relayer cannot perform attack anymore
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            RELAYER,
            RELAYER_ROLE
        ));

        vm.prank(RELAYER);
        mainnetController.cooldownAssetsSUSDe(1);

        // Funds have been locked in the silo this whole time
        assertEq(usde.balanceOf(almProxy), 0);
        assertEq(usde.balanceOf(silo),     startingSiloBalance + 1_000_000e18 + 1);  // 1 wei deposit as well

        // Backstop relayer can unstake the funds
        vm.prank(backstopRelayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(almProxy), 1_000_000e18 + 1);
        assertEq(usde.balanceOf(silo),     startingSiloBalance);
    }

}

contract MainnetController_Maple_Attack_Tests is Maple_TestBase {

    function test_attack_compromisedRelayer_delayRequestMapleRedemption() external {
        deal(address(usdc), almProxy, 1_000_000e6);

        vm.prank(RELAYER);
        mainnetController.depositERC4626(address(SYRUP), 1_000_000e6, 0);

        // Malicious relayer delays the request for redemption for 1m
        // because new requests can't be fulfilled until the previous is fulfilled or cancelled
        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Cannot process request
        vm.expectRevert("WM:AS:IN_QUEUE");
        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);

        // Freezer can remove the compromised relayer and fallback to the governance relayer
        vm.prank(FREEZER);
        accessControls.removeRelayer(RELAYER);

        // Compromised relayer cannot perform attack anymore
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            RELAYER,
            RELAYER_ROLE
        ));

        vm.prank(RELAYER);
        mainnetController.requestMapleRedemption(address(SYRUP), 1);

        // Governance relayer can cancel and submit the real request
        vm.startPrank(backstopRelayer);
        mainnetController.cancelMapleRedemption(address(SYRUP), 1);
        mainnetController.requestMapleRedemption(address(SYRUP), 500_000e6);
        vm.stopPrank();
    }

}
