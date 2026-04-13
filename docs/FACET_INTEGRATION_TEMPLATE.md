# New Facet Integration Template

Fill out every section of this document before an agent begins implementation.
An agent given this completed template plus `FACET_STANDARDS.md` and `FACET_TESTING.md` should be able to produce a correct, fully-tested, PR-ready facet with no additional guidance.

Delete all `<!-- instructions -->` comments before submitting.

---

## 1. Integration Overview

**Protocol name:** <!-- e.g. "Aave V3" -->

**Facet name:** <!-- e.g. "AaveV3Facet" -->

**Integration ID:** <!-- e.g. "AAVE_V3_FACET" — uppercase snake case, globally unique -->

**One-sentence description:**
<!-- What does this facet do? e.g. "Supplies and withdraws collateral from Aave V3 lending pools." -->

**Chains:**
- [ ] Mainnet
- [ ] Base
- [ ] Arbitrum
- [ ] Optimism
- [ ] Avalanche
- [ ] Other: ___

**Source of truth for contract addresses:**
<!-- Always use spark-address-registry. Specify the chain files and field names. -->
- Mainnet: `spark-address-registry/src/Ethereum.sol` → `FIELD_NAME`
- Base: `spark-address-registry/src/Base.sol` → `FIELD_NAME`

---

## 2. External Protocol Contracts

<!-- List every external contract this facet will call. All addresses must come from spark-address-registry.
     If an address is not in the registry, it must be added there first — never hardcode. -->

| Variable Name | Description | Registry Source |
|---|---|---|
| `POOL` | Aave V3 Pool | `Ethereum.AAVE_V3_POOL` |
| ... | ... | ... |

---

## 3. Constructor Immutables

<!-- List all immutable addresses injected via the constructor.
     Each must have a zero-address guard and be exposed as a view function in the interface. -->

| Name | Type | Description | Value Source |
|---|---|---|---|
| `POOL` | `address` | Aave V3 lending pool | `spark-address-registry/Ethereum.sol → AAVE_V3_POOL` |
| ... | ... | ... | ... |

---

## 4. Facet Storage

<!-- Per-facet state that persists between calls.
     This lives in an ERC-7201 isolated storage slot.
     The namespace will be: sky.pau.storage.<FacetName>.v1 -->

| Field | Type | Description |
|---|---|---|
| `maxSlippages` | `mapping(address aToken => uint256)` | Max slippage per market in 1e18 |
| ... | ... | ... |

Leave blank if the facet has no per-facet state.

---

## 5. Rate Limits

<!-- Every operation that moves value must have a rate limit.
     For each operation, specify the key constant name, key type, and direction. -->

| Constant | Key String | Key Type | Direction | Description |
|---|---|---|---|---|
| `LIMIT_DEPOSIT` | `"LIMIT_AAVE_DEPOSIT"` | `address` (aToken) | Decrease | Outflow per aToken market |
| `LIMIT_WITHDRAW` | `"LIMIT_AAVE_WITHDRAW"` | `address` (aToken) | Decrease | Inflow per aToken market |
| ... | ... | ... | ... | ... |

Key type determines which helper to use from `RateLimitHelpers.sol`:
- `address` → `makeAddressKey(key, addr)`
- `address + address` → `makeAddressAddressKey(key, a, b)`
- `uint32` → `makeUint32Key(key, n)`
- (see `FACET_STANDARDS.md` section 6 for full list)

---

## 6. Relayer Functions (Operations)

<!-- One sub-section per relayer function. These execute DeFi operations — they call external protocols through the proxy. -->

### 6.1 `deposit`

**Controller selector:** `deposit<Protocol>(address aToken, uint256 amount)`
<!-- The name exposed externally on the Controller — must be namespaced (no two facets share a selector) -->

**Facet selector:** `deposit(address aToken, uint256 amount)`
<!-- The name on the facet contract -->

**What it does:**
1. Decrease `LIMIT_DEPOSIT` rate limit by `amount` for `aToken`
2. Read `maxSlippage` for `aToken` — revert if not set
3. Read `underlying` and `pool` from `aToken` contract
4. Approve `underlying` to `pool` via `ApproveLib.approve`
5. Record `aToken` balance before call
6. Call `pool.supply(underlying, amount, proxy, 0)` via `proxy.doCall`
7. Assert received aTokens ≥ `amount * maxSlippage / 1e18`
8. Emit `<Protocol>Deposit(aToken, amount)`

**Reverts:**
- `"<Protocol>Facet/max-slippage-not-set"` — maxSlippage == 0
- `"<Protocol>Facet/slippage-too-high"` — received aTokens below threshold
- Rate limit exceeded (from IRateLimits)

---

### 6.2 `withdraw`

<!-- Repeat pattern for each additional relayer function -->

---

## 7. Admin Setter Functions

<!-- One sub-section per admin setter. These configure per-facet state. -->

### 7.1 `setMaxSlippage`

**Controller selector:** `set<Protocol>MaxSlippage(address aToken, uint256 maxSlippage)`

**Facet selector:** `setMaxSlippage(address aToken, uint256 maxSlippage)`

**What it does:**
1. Validate `aToken != address(0)`
2. Write `maxSlippage` to `FacetStorage.maxSlippages[aToken]`
3. Emit `<Protocol>MaxSlippageSet(aToken, maxSlippage)`

**Reverts:**
- `"<Protocol>Facet/aToken-zero-address"` — aToken is zero address

---

## 8. View Functions

<!-- One sub-section per view function. These expose facet state read-only. -->

### 8.1 `getMaxSlippage`

**Controller selector:** `get<Protocol>MaxSlippage(address aToken)`

**Facet selector:** `getMaxSlippage(address aToken)`

**Returns:** `uint256 maxSlippage` — current maxSlippage for `aToken`, 0 if not set

---

## 9. Events

<!-- List all events emitted by this facet, with all parameters. -->

| Event | Parameters | Emitted when |
|---|---|---|
| `<Protocol>Deposit` | `address indexed aToken, uint256 amount` | On successful deposit |
| `<Protocol>Withdraw` | `address indexed aToken, uint256 amountWithdrawn` | On successful withdrawal |
| `<Protocol>MaxSlippageSet` | `address indexed aToken, uint256 maxSlippage` | On setMaxSlippage |

---

## 10. Wiring Table

<!-- Complete mapping from Controller selector → Facet selector.
     Every function (relayer, admin, view) must have a wire entry.
     This table is used to construct the IEnumerableIntegrations.Wire[] array in tests and deployment. -->

| # | Controller-Facing Selector | Facet Selector |
|---|---|---|
| 0 | `set<Protocol>MaxSlippage(address,uint256)` | `setMaxSlippage(address,uint256)` |
| 1 | `get<Protocol>MaxSlippage(address)` | `getMaxSlippage(address)` |
| 2 | `deposit<Protocol>(address,uint256)` | `deposit(address,uint256)` |
| 3 | `withdraw<Protocol>(address,uint256)` | `withdraw(address,uint256)` |

---

## 11. External Protocol Reference

<!-- Paste or summarize the relevant external interface. This is what the facet will call.
     Include only the functions this facet actually calls. -->

```solidity
// Source: <protocol docs URL or Etherscan link>
interface IProtocolPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IATokenLike {
    function POOL() external view returns (address);
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
}
```

---

## 12. Known Edge Cases and Risks

<!-- Anything the implementing agent should watch for. -->

- [ ] Does the external protocol use fee-on-transfer tokens? If so, record balance before/after and use the delta — not the input amount.
- [ ] Does the external protocol return less than requested on withdrawal (e.g. dust)? Use returned amount for rate limit, not input.
- [ ] Does the external protocol have a reentrancy risk (calls back into caller)? Note here.
- [ ] Are there any protocol-specific revert conditions that need to be handled or surfaced?
- [ ] Is this integration chain-specific? Note any chains where it should NOT be deployed.
- [ ] Are there any gas-heavy loops or unbounded operations?

---

## 13. PR Scope

<!-- Define exactly what goes into the PR. Keep it small. -->

This PR should include:
- [ ] `src/facets/<protocol>/<Protocol>Facet.sol`
- [ ] `src/facets/<protocol>/I<Protocol>Facet.sol`
- [ ] `test/integration/facets/<Protocol>Facet.t.sol`
- [ ] `test/mainnet-fork/<Protocol>.t.sol` (if mainnet integration)
- [ ] `test/base-fork/<Protocol>.t.sol` (if Base integration)
- [ ] No changes to existing contracts

This PR should NOT include:
- Deployment scripts (separate PR)
- Changes to Controller, Beacon, or FacetBase
- Other facet modifications
- Documentation updates unrelated to this facet

---

## 14. Acceptance Criteria

The PR is ready for engineer review when:

- [ ] `forge build` — zero errors, zero warnings on new files
- [ ] `forge test --match-path test/integration/facets/<Protocol>Facet.t.sol` — all pass
- [ ] `forge test --match-path test/unit/**` — all pass
- [ ] `forge test --match-path test/integration/**` — all pass
- [ ] All admin setter tests present (reentrancy, unauthorized, input validation, happy path)
- [ ] All relayer tests present (reentrancy, unauthorized, rate limit, config-not-set, happy path)
- [ ] ERC-7201 slot computed and documented inline
- [ ] All events declared and emitted
- [ ] All functions have full NatSpec in the interface
- [ ] No hardcoded protocol addresses — constructor immutables only
- [ ] No new findings introduced (run security checklist from `FACET_STANDARDS.md` section 16)
