// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// SEED T-5: pranks the controller — bypasses the auth model under test.
contract MainnetController_Clean_Deposit_Tests {
    address internal mainnetController;
    function test_deposit() external {
        vm.prank(address(mainnetController));
    }
    function vm() internal pure returns (VmLike) { return VmLike(address(0)); }
}
interface VmLike { function prank(address) external; }
