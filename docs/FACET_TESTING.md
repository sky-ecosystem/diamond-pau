# Facet Testing Standards

This document defines the required test coverage for every PAU facet. It is the companion to `FACET_STANDARDS.md`.

An agent building a new facet must produce passing tests for all patterns described here before submitting a PR.

---

## 1. Test File Location

```
test/integration/facets/<Protocol>Facet.t.sol    ← required for all facets
test/mainnet-fork/<Protocol>.t.sol               ← required if mainnet integration exists
test/base-fork/<Protocol>.t.sol                  ← required if Base integration exists
```

A facet is considered adequately covered only if it has tests in at least one tree. Mock-based integration tests are always required. Fork tests are additionally required for any facet that interacts with live deployed contracts.

---

## 2. Integration Test Structure

Every `test/integration/facets/<Protocol>Facet.t.sol` must follow this structure:

```solidity
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { I<Protocol>Facet }        from "../../../src/facets/<protocol>/I<Protocol>Facet.sol";
import { IEnumerableIntegrations } from "../../../src/interfaces/IEnumerableIntegrations.sol";

import { <Protocol>Facet } from "../../../src/facets/<protocol>/<Protocol>Facet.sol";

import { Integration_TestBase } from "../TestBase.t.sol";

// Controller-facing interface: namespaced selectors that map to this facet.
// Only declare the functions actually wired to this facet.
interface IControllerLike {
    function set<Protocol>Param(address key, uint256 value) external;
    function get<Protocol>Param(address key) external view returns (uint256);
    function updateIntegrations(bytes32[] memory integrationIds) external;
}

// ─── TestBase ────────────────────────────────────────────────────────────────

abstract contract <Protocol>Facet_TestBase is Integration_TestBase {

    IControllerLike internal controller;

    // Mock addresses for the protocol's external contracts.
    address internal mockProtocol = makeAddr("mockProtocol");
    address internal asset        = makeAddr("asset");

    function setUp() external {
        controller = IControllerLike(_deploy());

        // Deploy facet. Pass constructor args if needed.
        address facet = address(new <Protocol>Facet(/* constructor args */));
        vm.label(facet, "<Protocol>Facet");

        // Wire all selectors.
        IEnumerableIntegrations.Wire[] memory wires = new IEnumerableIntegrations.Wire[](/* N */);
        wires[0] = IEnumerableIntegrations.Wire(
            IControllerLike.set<Protocol>Param.selector,
            I<Protocol>Facet.setParam.selector
        );
        // ... all wires

        IEnumerableIntegrations.Config memory config = IEnumerableIntegrations.Config(facet, wires);

        vm.prank(beaconAdmin);
        beacon.setIntegration("<PROTOCOL>_FACET", config);

        bytes32[] memory integrationIds = new bytes32[](1);
        integrationIds[0] = "<PROTOCOL>_FACET";

        vm.prank(admin);
        controller.updateIntegrations(integrationIds);
    }

}
```

---

## 3. Required Test Coverage — Admin Setters

For EVERY admin setter (`onlyRole(DEFAULT_ADMIN_ROLE)`), the following tests are required:

### 3.1 Reentrancy guard
```solidity
function test_set<Param>_reentrancy() external {
    _setEntered(address(controller));
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    controller.set<Protocol><Param>(makeAddr("key"), value);
}
```

### 3.2 Unauthorized caller
```solidity
function test_set<Param>_unauthorizedAccount() external {
    vm.expectRevert(abi.encodeWithSignature(
        "AccessControlUnauthorizedAccount(address,bytes32)",
        address(this),
        DEFAULT_ADMIN_ROLE
    ));
    controller.set<Protocol><Param>(makeAddr("key"), value);
}
```

### 3.3 Input validation (one test per require)
```solidity
function test_set<Param>_zeroAddress() external {
    vm.prank(admin);
    vm.expectRevert("<Protocol>Facet/key-zero-address");
    controller.set<Protocol><Param>(address(0), value);
}
```

### 3.4 Happy path — state change + event + reentrancy guard check
```solidity
function test_set<Param>() external {
    address key = makeAddr("key");

    assertEq(controller.get<Protocol><Param>(key), 0);  // initial state

    vm.prank(admin);
    vm.expectEmit(address(controller));
    emit I<Protocol>Facet.<Protocol><Param>Set(key, value1);
    controller.set<Protocol><Param>(key, value1);

    assertEq(controller.get<Protocol><Param>(key), value1);

    vm.record();  // start recording storage writes

    vm.prank(admin);
    vm.expectEmit(address(controller));
    emit I<Protocol>Facet.<Protocol><Param>Set(key, value2);
    controller.set<Protocol><Param>(key, value2);

    assertEq(controller.get<Protocol><Param>(key), value2);

    _assertReentrancyGuardWrittenToTwice(address(controller));  // confirm guard executed
}
```

Note: `vm.record()` before the second call + `_assertReentrancyGuardWrittenToTwice` confirms the reentrancy guard was active (wrote twice: set entered → set not-entered). Always include this on the happy path.

---

## 4. Required Test Coverage — Relayer Functions

For EVERY relayer function (`onlyRole(RELAYER_ROLE)`), the following tests are required:

### 4.1 Reentrancy guard
```solidity
function test_<operation>_reentrancy() external {
    _setEntered(address(controller));
    vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    vm.prank(relayer);
    controller.<protocol><Operation>(asset, amount);
}
```

### 4.2 Unauthorized caller
```solidity
function test_<operation>_unauthorizedAccount() external {
    vm.expectRevert(abi.encodeWithSignature(
        "AccessControlUnauthorizedAccount(address,bytes32)",
        address(this),
        RELAYER_ROLE
    ));
    controller.<protocol><Operation>(asset, amount);
}
```

### 4.3 Rate limit exceeded
```solidity
function test_<operation>_rateLimitExceeded() external {
    // Ensure rate limit is set to a value lower than the operation amount.
    vm.expectRevert(/* rate limit revert */);
    vm.prank(relayer);
    controller.<protocol><Operation>(asset, amountAboveLimit);
}
```

### 4.4 Required config not set (if applicable)
```solidity
function test_<operation>_paramNotSet() external {
    vm.expectRevert("<Protocol>Facet/param-not-set");
    vm.prank(relayer);
    controller.<protocol><Operation>(asset, amount);
}
```

### 4.5 Happy path — full call + state assertions + event
```solidity
function test_<operation>() external {
    // Setup: configure param, set rate limit, mock external call expectations.
    // ...

    vm.prank(relayer);
    vm.expectEmit(address(controller));
    emit I<Protocol>Facet.<Protocol><Operation>(asset, amount);
    controller.<protocol><Operation>(asset, amount);

    // Assert: proxy balance changes, rate limit consumed, return value (if any).
    // ...

    _assertReentrancyGuardWrittenToTwice(address(controller));
}
```

### 4.6 Slippage check (if applicable)
```solidity
function test_<operation>_slippageTooHigh() external {
    // Mock external call to return fewer tokens than slippage allows.
    vm.expectRevert("<Protocol>Facet/slippage-too-high");
    vm.prank(relayer);
    controller.<protocol><Operation>(asset, amount);
}
```

---

## 5. Rate Limit Interaction Tests

For any facet with both deposit and withdraw operations:

```solidity
function test_withdraw_increasesDepositRateLimit() external {
    // Show that withdrawing X increases deposit capacity by X.
}

function test_deposit_decreasesDepositRateLimit() external {
    // Show that depositing X decreases deposit capacity by X.
}

function test_withdraw_decreasesWithdrawRateLimit() external {
    // Show that withdrawing X decreases withdraw capacity by X.
}
```

---

## 6. Test Naming Convention

```
test_<functionName>_<conditionUnderTest>
```

Examples:
- `test_setMaxSlippage_reentrancy`
- `test_setMaxSlippage_unauthorizedAccount`
- `test_setMaxSlippage_aTokenZeroAddress`
- `test_setMaxSlippage` (happy path — no suffix)
- `test_deposit_rateLimitExceeded`
- `test_deposit_slippageTooHigh`
- `test_deposit` (happy path)

---

## 7. Test Contract Naming Convention

```solidity
contract Controller_<Protocol>Facet_Admin_Tests   is <Protocol>Facet_TestBase { ... }
contract Controller_<Protocol>Facet_Relayer_Tests is <Protocol>Facet_TestBase { ... }
```

---

## 8. Mocking External Protocol Calls

Use `vm.mockCall` for external protocol calls. Do NOT deploy real protocol contracts in mock-based integration tests.

```solidity
// Mock a return value
vm.mockCall(
    mockProtocol,
    abi.encodeCall(IProtocolLike.externalFunction, (asset, amount)),
    abi.encode(returnValue)
);

// Expect a call was made with specific args
vm.expectCall(
    mockProtocol,
    abi.encodeCall(IProtocolLike.externalFunction, (asset, amount))
);
```

For proxy calls (`doCall`), mock at the proxy target address, not at the proxy itself.

---

## 9. Fork Tests

Fork tests live in `test/mainnet-fork/`, `test/base-fork/`, or `test/avalanche-fork/`.

Requirements:
- Must use the live deployed contracts (real Aave pool, real USDC, etc.)
- Must inherit the chain's `ForkTestBase.t.sol`
- Must verify `ForkTestBase` wires the Controller/Beacon correctly (not the old `MainnetController`)
- Must cover the same relayer operation happy paths as the mock-based tests
- Must use `vm.prank(relayer)` with the actual relayer address from the fork environment
- Contract addresses must come from `spark-address-registry` — never hardcoded

---

## 10. Build and Test Verification

Before submitting any PR, the following must pass:

```bash
cd ~/projects/spark/diamond-pau

# Must compile cleanly
forge build

# All unit tests must pass
forge test --match-path "test/unit/**"

# All integration tests must pass
forge test --match-path "test/integration/**"

# The new facet's test file specifically
forge test --match-path "test/integration/facets/<Protocol>Facet.t.sol" -v
```

No test failures permitted. No compiler warnings on new code.

---

## 11. Coverage Checklist

Before marking a facet as done, verify every box:

```
Admin setters:
  [ ] reentrancy test
  [ ] unauthorized caller test
  [ ] zero-address test (if setter takes address)
  [ ] input validation tests (one per require)
  [ ] happy path: initial state → set → assert state + event + reentrancy guard

Relayer functions:
  [ ] reentrancy test
  [ ] unauthorized caller test
  [ ] rate limit exceeded test
  [ ] required config not set test (if applicable)
  [ ] slippage too high test (if applicable)
  [ ] happy path: setup → call → assert state/balances + event + reentrancy guard

Rate limits:
  [ ] deposit decreases deposit limit
  [ ] withdraw decreases withdraw limit
  [ ] withdraw increases deposit limit

Build:
  [ ] forge build — zero errors, zero warnings on new files
  [ ] forge test --match-path test/unit/** — all pass
  [ ] forge test --match-path test/integration/** — all pass
```
