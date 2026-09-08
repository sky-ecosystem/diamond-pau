// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

// Gate fixture: a test snippet using only sanctioned idioms (real role holders pranked,
// no system-contract state rewrites). Pins the test-lint's false-positive behavior.

contract MainnetController_Clean_Deposit_Tests {

    address internal allocator;

    function test_deposit() external {
        // vm.prank(allocator) — the real relayer multisig from the registry
        // vm.prank(Ethereum.SPARK_PROXY) — governance executor for admin config
    }

}
