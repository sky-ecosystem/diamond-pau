# Parallel Controller Upgrade: Diamond PAU alongside the legacy ALM Controller

This document proposes onboarding the Diamond PAU system on Ethereum mainnet alongside the existing
(legacy) ALM Controller. Both controllers custody the same `ALMProxy`. The Diamond PAU Controller gets
its own dedicated `RateLimits` instance and is wired with three integrations: `UNISWAP_V4_FACET`,
`CCTP_FACET` (CCTP v2) and `DUAL_POOL_FACET`.

No funds are migrated, no custody contract is redeployed, and the legacy controller is not modified.
Exposure is created by a role grant rather than by a deposit, and it is bounded by the rate limits
governance sets on the new instance.

The central property for risk planning:

> The Diamond PAU Controller holds the `CONTROLLER` role on the `ALMProxy`, which confers unrestricted
> authority over the full `ALMProxy` balance. It is constrained **not** by the proxy, but by the set of
> call selectors wired into it and by the rate limits attached to those specific functions.

---

## 1. Target topology

<p align="center">
  <img src="./multicontroller.png" alt="Parallel controller setup" height="700px" style="margin-right:100px;"/>
</p>

`ALLOCATOR_ROLE` is held by the `AdministeredAgent` on `AccessControls`, not on the Controller itself.
The Controller and its facets hold no role state of their own: every `onlyRole` check, for both
`ALLOCATOR_ROLE` and `DEFAULT_ADMIN_ROLE`, is an external call into `AccessControls`. This is the
structural difference from the legacy controller, which stores `RELAYER` and `FREEZER` internally.

One contract is omitted from the diagram for readability but is part of the deployment: `Beacon`, the
canonical registry of integration configs (facet address plus selector wiring). The Controller syncs
its local dispatch table from the Beacon via `updateIntegrations`, and the Beacon is the only place
facet addresses are registered.

### 1.1 Contract inventory

**Reused, unchanged:**

| Contract | Mainnet address | Change |
| --- | --- | --- |
| `ALMProxy` | `0x1601843c5E9bC251A3272907010AFa41Fa18347E` | One `grantRole(CONTROLLER, diamondController)` |
| `RateLimits` (legacy) | `0x7A5FD5cf045e010e62147F065cEAe59e5344b188` | **None.** The Diamond PAU Controller is never granted a role on this instance |
| `MainnetController` (legacy) | `0x5c46Fc65855c0C7465a1EA85EEA0B24B601502D3` | None |
| `SPARK_PROXY` | `0x3300f198988e4C9C63F75dF86De36421f06af8c4` | None, remains admin everywhere |
| `ALM_RELAYER_MULTISIG` | `0x8a25A24EDE9482C4Fc0738F99611BE58F1c839AB` | Additionally becomes agent Actor |
| `ALM_BACKSTOP_RELAYER_MULTISIG` | `0x8Cc0Cb0cfB6B7e548cfd395B833c05C346534795` | Additionally becomes agent Actor |
| `ALM_FREEZER_MULTISIG` | `0x90D8c80C028B4C09C0d8dcAab9bbB057F0513431` | Additionally becomes agent Revoker |

**Already deployed, reused unchanged.** Addresses from
[`sky-pau-registry/src/Ethereum.sol`](https://github.com/sky-ecosystem/sky-pau-registry/blob/master/src/Ethereum.sol),
the canonical source of truth.

| Contract | Mainnet address | Role in this upgrade |
| --- | --- | --- |
| `Beacon` | `0x829dC2b7E94B1954F0764E573f2E0d45Afa28199` | Holds the integration configs the Controller syncs from |
| `PAUFactory` | `0x69A5d548830AC2A4Ba90A44a2C75BDA71f97fc66` | Deploys the new `AccessControls`, `RateLimits` and `Controller` |
| `AdministeredAgentFactory` | `0x2968c3b5478cF93B70aB1e24255d4EDBBd27a089` | Deploys the new `AdministeredAgent` |
| `UniswapV4Facet` | `0x75D35ffB8e6B871E12EB549CcF6afD324c46E47D` | Integration 1 |
| `CCTPFacet` | `0xADf62692340e46EF90336f2e75ce3b37f1148873` | Integration 2 (CCTP v2) |

**Still to be deployed:**

| Contract | Source | Notes |
| --- | --- | --- |
| `AccessControls` | `PAUFactory.deployAccessControls` | Admin: `SPARK_PROXY` |
| `RateLimits` | `PAUFactory.deployRateLimits` | Admin: `SPARK_PROXY`. Dedicated to this Controller, see section 4 |
| `Controller` | `PAUFactory.deployController` | Points at the **existing** `ALMProxy` and the **new** `RateLimits` |
| `AdministeredAgent` | `AdministeredAgentFactory.deploy` | Actors: relayer and backstop relayer multisigs. Revoker: freezer multisig |
| `DualPoolFacet` | `diamond-pau` release | **Not yet available.** |

Four contracts are new, none custody funds, and none hold privileges outside their own stack. **No new
`ALMProxy` is deployed**, which is the deliberate difference from the standard `DefaultPAUAssembler`
flow, see section 5.

---

## 2. Scope of the parallel controller upgrade

### 2.1 What is deployed, granted and onboarded

**Deployed** (permissionless, before any spell): `AccessControls`, `RateLimits`, `Controller`,
`AdministeredAgent`.

**Granted** (Spark spell):

- `CONTROLLER` on the existing `ALMProxy`, to the new Controller.
- `CONTROLLER` on the **new** `RateLimits` only, to the new Controller.
- `ALLOCATOR_ROLE` on the new `AccessControls`, to the `AdministeredAgent`.
- Actors and revoker on the `AdministeredAgent`.

**Onboarded**, three integrations:

| Facet | Wires | Allocator functions that can move value | Admin setters | External targets |
| --- | --- | --- | --- | --- |
| `UniswapV4Facet` | 17 | 4: `mintPosition`, `increasePosition`, `decreasePosition`, `swap` | `setMaxSlippage`, `setTickLimits` | immutable `positionManager`, `router`, `permit2` |
| `CCTPFacet` | 10 | 1: `transfer` | `setDomainParameters` | immutable `cctp`, `usdc` |
| `DualPoolFacet` | 13 | 2: `deposit`, `withdraw` | `setMaxSlippage`, `setPriceRatio` | immutable `hook` |

Seven allocator functions in total can move value. Every one is `nonReentrant`, gated on
`ALLOCATOR_ROLE`, rate limited, and targets an address fixed in facet bytecode at construction.

`CCTPFacet` is CCTP **v2** only: it calls the seven argument `depositForBurn` with `destinationCaller`,
`maxFee` and `minFinalityThreshold`. The legacy controller implements CCTP **v1** (four argument
`depositForBurn`). The two are different routes for the same operation, not duplicates.

### 2.2 What this upgrade does not do

- No new `ALMProxy`. The custody contract keeps its bytecode, storage, admin, approvals and positions.
- No fund or position migration.
- No change to the legacy controller, its roles, or its rate limit keys.
- No shared rate limit state between the two controllers.

### 2.3 The authority being granted, and what contains it

`ALMProxy` is intentionally minimal. Its entire authorization surface is `doCall`, `doCallWithValue`
and `doDelegateCall`, each `onlyRole(CONTROLLER)`. There is no per-target allowlist, no per-asset
scoping and no notion of a budget. Granting `CONTROLLER` is, at the proxy level, equivalent to granting
full authority over every asset the `ALMProxy` holds. This is the same trust level the legacy
controller already has, and no narrower grant exists.

Containment comes entirely from the Controller's own dispatch table:

```solidity
fallback() external payable {
    require(msg.data.length >= 4, InvalidCallDataLength(msg.data.length));
    Dispatch storage dispatch = _getControllerStorage().dispatches[msg.sig];
    address facet = dispatch.facet;
    require(facet != address(0), CallSelectorNotWired(msg.sig));
    ...facet.delegatecall(abi.encodePacked(dispatch.delegateSelector, msg.data[4:]));
}
```

There is no generic passthrough, no `execute(target, data)`, and no path for an allocator to reach
`doCall` with arbitrary calldata. The reachable surface is exactly the synced integration set.

Within that surface, a compromised allocator key cannot forge a pool (`UniswapV4Facet` resolves the
`PoolKey` from the position manager and asserts `keccak256(abi.encode(poolKey)) == poolId`;
`DualPoolFacet` asserts `key.hooks == hook`), cannot choose a call target (every target is a facet
immutable), cannot choose a CCTP recipient (`mintRecipient` is governance set per destination domain),
and cannot leave a standing approval (Permit2 approvals are set and zeroed in the same call).

**The proxy provides no defence in depth.** Any statement of the form "the Diamond PAU can only
interact with these three integrations" is a statement about the Controller's synced integration set,
which is governance mutable. It is not enforced by the custody contract. Section 6.3 develops this.

---

## 3. Access control layout after the upgrade

| Contract | Role | Holder(s) |
| --- | --- | --- |
| `ALMProxy` (existing) | `DEFAULT_ADMIN_ROLE` | `SPARK_PROXY` |
| `ALMProxy` (existing) | `CONTROLLER` | legacy `MainnetController`, **new Diamond PAU `Controller`** |
| `RateLimits` (legacy) | `DEFAULT_ADMIN_ROLE` | `SPARK_PROXY` |
| `RateLimits` (legacy) | `CONTROLLER` | legacy `MainnetController` only, unchanged |
| `RateLimits` (new) | `DEFAULT_ADMIN_ROLE` | `SPARK_PROXY` |
| `RateLimits` (new) | `CONTROLLER` | **new Diamond PAU `Controller`** only |
| legacy `MainnetController` | `DEFAULT_ADMIN_ROLE` | `SPARK_PROXY` |
| legacy `MainnetController` | `RELAYER` | `ALM_RELAYER_MULTISIG` |
| legacy `MainnetController` | `FREEZER` | `ALM_FREEZER_MULTISIG` |
| new `AccessControls` | `DEFAULT_ADMIN_ROLE` | `SPARK_PROXY` |
| new `AccessControls` | `ALLOCATOR_ROLE` | `AdministeredAgent` |
| existing `Beacon` | `DEFAULT_ADMIN_ROLE` | Sky governance, not `SPARK_PROXY` |
| `AdministeredAgent` | admin | `SPARK_PROXY` |
| `AdministeredAgent` | actor | `ALM_RELAYER_MULTISIG`, `ALM_BACKSTOP_RELAYER_MULTISIG` |
| `AdministeredAgent` | revoker | `ALM_FREEZER_MULTISIG` |
| `AdministeredAgent` | grantor | see open question 1 |

Notes:

- The Diamond PAU `Controller` holds no roles of its own. Its admin functions (`updateIntegrations`,
  `removeIntegrations`) authorize against `DEFAULT_ADMIN_ROLE` on the external `AccessControls`, and
  facets do the same via `Facet.onlyRole`. Whoever holds `DEFAULT_ADMIN_ROLE` there governs the
  Controller **and** every facet admin setter.
- `AdministeredAgent` maintains four independent address sets. `admin` can do everything; `actor` can
  call `call`, `batchCall` and `sendValue`; `grantor` can only `addActor`; `revoker` can only
  `removeActor`. The last admin cannot be removed.
- The agent holds **no** controller reference. Targets are passed per call and the only restriction is
  `target != address(this)`. One agent can therefore drive N controllers, and its effective authority
  is the union of every role ever granted to its address. That is a standing invariant to monitor, not
  a code guarantee.
- The relayer multisigs do not hold `ALLOCATOR_ROLE` directly. The Controller observes
  `msg.sender == AdministeredAgent` regardless of which actor originated the call, so the two relayers
  are indistinguishable from the Controller's perspective and share the same rate limits.
- `CONTROLLER` is `keccak256("CONTROLLER")` in both codebases and both `ALMProxy` implementations use
  the identical constant, so the grant is a standard `grantRole` from `SPARK_PROXY`.

### 3.1 Freeze and revocation paths

| Scenario | Legacy controller | Diamond PAU controller |
| --- | --- | --- |
| Compromised relayer key | `ALM_FREEZER_MULTISIG` calls `MainnetController.removeRelayer(relayer)` | `ALM_FREEZER_MULTISIG` calls `AdministeredAgent.removeActor(relayer)`, once per affected actor |
| Disable one integration | not applicable, monolithic | `SPARK_PROXY` calls `Controller.removeIntegrations([id])`, or zeroes that facet's rate limit keys |
| Full revocation | `SPARK_PROXY` revokes `CONTROLLER` on `ALMProxy` | `SPARK_PROXY` revokes `CONTROLLER` on `ALMProxy`, or revokes `ALLOCATOR_ROLE` from the agent |

Two properties the runbook must state explicitly:

1. A single freezer action does **not** halt both controllers. Two separate transactions are required,
   and the Diamond side needs one per actor.
2. The shared custody contract `ALMProxy` `0x1601843c...` is the non-freezable `spark-alm-controller`
   v1.0.0 instance and **has no freeze function at all**. `ALM_PROXY_FREEZABLE`
   (`0xe5c6318456a7Cb6f74f93B4eee4616dB5fcef699`) is a different proxy doing a different job (Spark
   Savings rate setting, Morpho allocation, SparkLend cap automation) and is not the SLL custody
   account. There is no global kill switch for the custody account under either controller.

---

## 4. Rate limits

The Diamond PAU Controller gets a **dedicated** `RateLimits` instance, deployed via
`PAUFactory.deployRateLimits(SPARK_PROXY)`. `rateLimits` is written to the Controller's shared storage
by the constructor and has no setter, so the instance is bound at deploy time. Pointing the Controller
at a different instance later would require deploying a new Controller and repeating the full wiring
sequence.

### 4.1 Why a dedicated instance

`RateLimits.triggerRateLimitDecrease` and `triggerRateLimitIncrease`
([src/RateLimits.sol:72-113](../src/RateLimits.sol#L72-L113)) are `onlyRole(CONTROLLER)` and accept an
**arbitrary `bytes32 key`**. The role is not key scoped.

A single instance shared with the legacy controller would therefore give the Diamond PAU Controller,
and every facet ever synced into it, write access to **every** legacy budget: PSM, mint and burn, Aave,
ERC-4626, LayerZero, CCTP, all of them. The relationship would be symmetric, with legacy code able to
refill Diamond budgets and defeat a deliberate drain. A dedicated instance makes that authority empty
in both directions and is the strongest single security property of this proposal.

It also neutralizes several exact key collisions. These are byte identical derivations, not merely
similar ones:

| Operation | Legacy derivation | Diamond derivation | Would collide |
| --- | --- | --- | --- |
| UniV4 aggregate deposit | `keccak(keccak("LIMIT_UNISWAP_V4_DEPOSIT"), poolId)` | identical | Yes |
| UniV4 aggregate withdraw | `keccak(keccak("LIMIT_UNISWAP_V4_WITHDRAW"), poolId)` | identical | Yes |
| UniV4 swap | `keccak(LIMIT_SWAP, poolId)` | `keccak(LIMIT_SWAP, token, poolId)` | No |
| CCTP total | `keccak("LIMIT_USDC_TO_CCTP")` | same constant | Yes |
| CCTP per domain | `makeUint32Key(LIMIT_USDC_TO_DOMAIN, domain)` | same derivation | Yes |
| UniV4 per asset, DualPool | not present | new keys | n/a |

Legacy UniV4 is live today with configured pools (PYUSD/USDS and USDT/USDS from spell `20260129`,
USDG/USDS and RLUSD/USDS from `20260813`), and legacy CCTP v1 is live on all its domains. Under a
shared instance those budgets would have been coupled from the first allocator call.

### 4.2 The cost: capacity becomes additive

For every operation reachable on both controllers, total capacity is the legacy budget **plus** the
Diamond budget. This is live from day one for Uniswap V4, and for CCTP until the legacy v1 keys are
zeroed in stage 4.

Invariant to adopt in spell review: **the number risk approves is the sum, and any spell changing one
side must state the other side's current value.** This is the direct cost of the isolation in 4.1, and
6.4 covers how it is reconciled and then removed.

### 4.3 Keys and denominations

All facet limits use `_decreaseRateLimit`, never a permissive try-variant, so an unset key
(`maxAmount == 0`) reverts the call.

| Facet | Keys per onboarded unit |
| --- | --- |
| `UniswapV4Facet` | 8 per pool: 2 aggregate (18 decimal normalized) and 6 per asset (raw token decimals), across deposit, withdraw and swap |
| `CCTPFacet` | 2: `toCCTPRateLimitKey()` flat aggregate, plus `getToDomainRateLimitKey(domain)` per destination |
| `DualPoolFacet` | 4 per pool: aggregate and per asset, deposit and withdraw |

The canonical key lists belong in the spell, not here. Two denomination traps for whoever authors it:

- Aggregate keys are decremented with 18 decimal normalized amounts while per asset keys use the
  token's raw amount. A USDC per asset limit is expressed in 6 decimals, the aggregate limit covering
  the same flow in 18.
- The legacy swap limit is decremented with a **normalized** amount; the facet's swap limit uses the
  **raw** `amountIn`. A legacy swap value copied across for a 6 decimal token is wrong by `1e12`.

### 4.4 Facet configuration required

Facet settings live in each facet's ERC-7201 storage domain inside the Controller, so they are per
Controller and legacy values do not carry over. All are fail closed:

| Unset | Effect |
| --- | --- |
| `setTickLimits` | `mintPosition` and `increasePosition` revert with `UniswapV4Facet/tickLimits-not-set` |
| `setMaxSlippage` | `swap` reverts with `UniswapV4Facet/max-slippage-not-set` |
| `setDomainParameters` | `transfer` reverts with `CCTPFacet/domain-not-configured` |

`setTickLimits` accepts the all zero triple as a way to clear a pool's limits, which blocks liquidity
operations on that pool while leaving `swap` and `decreasePosition` available.

---

## 5. Deployment and rollout

`DefaultPAUAssembler` and the `sky-factories` variant both always call `deployALMProxy`, so neither can
be used here. `PAUFactory` is called directly, and the role wiring the assembler would have performed
is carried out explicitly in the spell. An assembler variant that accepts an existing proxy would be
reusable for future controllers joining an existing custody account, but it is new contract code
needing its own review and is kept off the critical path.

### 5.1 Deployment and grants

1. **Permissionless deploys.** `PAUFactory.deployAccessControls(SPARK_PROXY)`,
   `PAUFactory.deployRateLimits(SPARK_PROXY)`,
   `PAUFactory.deployController(accessControls, existingALMProxy, newRateLimits)`, and
   `AdministeredAgentFactory.deploy(SPARK_PROXY)`. Read back every constructor argument and admin
   cardinality before proceeding.
2. **Spark spell, grants.** `CONTROLLER` on the `ALMProxy`; `CONTROLLER` on the new `RateLimits`;
   `ALLOCATOR_ROLE` to the agent; agent actors and revoker.
3. **Sky spell, Beacon registration** per facet, since the Beacon is Sky owned infrastructure. Steps 2
   and 3 are independent, but step 4 depends on step 3.
4. **Spark spell, sync.** `Controller.updateIntegrations([id])`. Before syncing, read
   `Beacon.getConfig(id)` in the same transaction and require the facet address equals the hardcoded
   audited address and the wire count matches (17, 10, 13). This guard matters, see 6.3.
5. **Spark spell, configuration.** Rate limit keys first, then facet setters: tick limits and
   `maxSlippage` per pool for UniV4, `setDomainParameters` per domain for CCTP, `maxSlippage` and
   `priceRatio` per pool for DualPool. Facet key getter selectors are only reachable after step 4.

### 5.2 Staged rollout

Two rules govern the ramp:

> **No two stages advance in the same spell, and a cap increase never ships alongside a new
> integration.** Any anomaly must have exactly one candidate cause.

All advance criteria are expressed as elapsed time, round trip counts, multiples of the stage's own
cap, and binary monitoring gates. None depends on an absolute number, so the ramp is unaffected by
whatever caps risk sets.

| Stage | Enables | Advance criteria |
| --- | --- | --- |
| **0. Prerequisites** | No on-chain authority. Deploys, Beacon registration, test harness extension, registry constants, monitoring across both controllers and both rate limit instances, freeze rehearsal | Constructor arguments and admin cardinality read back as expected. Harness green **with the new instance actually covered**. Freeze rehearsed on a fork with a recorded wall clock time |
| **1. UniV4, one pool, minimum viable cap** | `UNISWAP_V4_FACET` only, one pool, caps at the smallest size that still produces a real operation. Legacy UniV4 untouched. Chosen first because it is the only facet with a line comparable legacy counterpart, so a discrepancy is observable against a known good baseline, and it has no cross-chain leg | N weeks in production with at least one full deposit to withdraw round trip per week. All 8 keys exercised and observed decrementing by the expected amount. No unexplained accounting delta between the two controllers' event streams. No reverts of unknown cause. One fork rehearsal of `removeIntegrations` and re-sync |
| **2. UniV4, higher caps and more pools** | Cap increases and additional pools. Still one facet | Cumulative volume at a stated multiple of the stage 1 aggregate deposit cap, incident free, measured from the **last cap change**. Hook review completed and recorded for every added pool, as a gate rather than a guideline (see 6.4). Legacy plus Diamond sum stated per pool in the spell |
| **3. CCTP v2, one domain** | `CCTP_FACET` with a small per domain cap on one destination whose `mintRecipient` is well established. Legacy v1 keys left non-zero so the fallback route stays available | `mintRecipient` independently verified as the destination `ALMProxy` by a second party. Destination confirmed able to receive v2 messages. Fee band set so the upper bound times the cap is an acceptable absolute loss. N successful transfers including one at the largest allowed chunk, to exercise the `burnLimitsPerMessage` loop. Every burn reconciled to a mint |
| **4. Retire legacy CCTP v1** | Zero the legacy aggregate and per domain CCTP keys. Removes CCTP capacity addition and consolidates the route. Possible only because the instances are separate | v2 proven per stage 3 for **every** domain legacy currently serves. Circle v1 deprecation timeline confirmed. No unattested in-flight v1 messages. Rollback spell pre-drafted |
| **5. DualPool** | Blocked on: merge to `dev`, inclusion in an audited release, deployment, `sky-pau-registry` entry, Beacon registration by Sky. Then repeat the stage 1 pattern from the smallest viable cap | Same shape as stage 1, plus the DualPool hook confirmed governance owned and non-upgradeable |
| **6. Steady state** | Optionally zero legacy UniV4 keys per pool to make Diamond PAU the sole UniV4 route, retiring capacity addition there too. Possible only with the dedicated instance | Product decision, not a risk gate |

**Standing de-ramp triggers.** Any one of these halts the ramp and freezes caps at the current stage:
an unexplained rate limit decrement; a balance-delta revert of unknown cause; a Beacon config change
Spark did not initiate; a facet address in `Controller.integrations()` differing from the audited
registry entry; any role granted to the `AdministeredAgent` address other than `ALLOCATOR_ROLE` on this
`AccessControls`.

### 5.3 Post-spell verification

- `Controller.integrations()` returns exactly the expected ids, each pointing at the audited registry
  address. This is the check that most directly substantiates section 2.
- `Controller.getDispatch(selector)` returns the facet for each wired selector and `address(0)` for a
  sample of legacy selectors (`mintUSDS`, `swapUSDSToUSDC`, `transferAsset`), demonstrating they are
  unreachable.
- `Controller.proxy()`, `.rateLimits()`, `.beacon()` and `.accessControls()` all read as expected, and
  `.rateLimits()` is **not** the legacy `0x7A5FD5cf...`.
- `ALMProxy.getRoleMemberCount(CONTROLLER) == 2` with both members expected. Legacy `RateLimits` still
  has exactly one `CONTROLLER` member. New `RateLimits` has exactly one.
- `AccessControls` and new `RateLimits` each have exactly one `DEFAULT_ADMIN_ROLE` member,
  `SPARK_PROXY`, with no residual deployer. `AdministeredAgent.adminCount() == 1`.
- Facet immutables read as expected, and all configured keys read back non-zero on the new instance.
- Legacy controller functional regression test confirming no behaviour change.
- A small round trip per onboarded facet, verifying the rate limit decrement on every affected key.

---

## 6. Risk assessment

Four risks matter for this upgrade: the Diamond PAU system is young, the stack is freshly deployed, a
facet reaches further than the integration it implements, and two controllers share one custody
account. Each is described below with what the current setup does about it and what remains.

### 6.1 The Diamond PAU system is new

**The risk.** A system without much production history immediately holds authority over a large
balance, so a latent bug surfaces at full size rather than at a size the protocol can absorb.

**What reduces it.** The stack is not uniformly new. Its parts have very different track records:

| Component | Production history |
| --- | --- |
| `ALMProxy` `0x1601843c...` (custody) | Unchanged since `spark-alm-controller` v1.0.0. Not redeployed, not migrated, no storage change in this upgrade |
| diamond-pau `ALMProxyFreezable` | Live in **Spark** production since spell `20251211`, instance rotated in `20260604`. Holds Spark Savings `SETTER_ROLE` on spUSDC, spUSDT, spETH and spPYUSD, Morpho allocator on two vaults, and SparkLend Cap Automator `UPDATE_ROLE` |
| Diamond `Controller`, `Beacon`, `AccessControls` dispatch stack | Live at **Grove**, alongside Grove's legacy controller, on Grove's existing proxy |
| `UniswapV4Facet` | Deployed and audited through the v1.14.0 release cycle. Its legacy counterpart is live and still being extended, most recently by spell `20260813` |
| `CCTPFacet` v1.0.0 | No production usage yet |
| `DualPoolFacet` | In progress |

The codebase carries 33 audit reports across v1.0.0 to v1.14.0 from five firms (Cantina,
ChainSecurity, Certora, Octane, Unvariant), so review is a per release cadence rather than a one time
event. Grove already runs this topology in production, at smaller scale and with a different
integration set, and does so with a *shared* `RateLimits` instance, which is a weaker configuration
than the dedicated instance proposed here.

**What remains.** `ALMProxyFreezable` is a permissioned forwarder, so its record says nothing about
the dispatch machinery itself (`fallback()`, `updateIntegrations`, facet `delegatecall`). That
machinery has production history only at Grove's scale, and time in production does not transfer
across asset scale. This risk is therefore handled by the staged ramp in 5.2 rather than argued away:
stages 1 and 2 buy production history at Spark scale at a cost bounded by the caps governance sets,
and nothing makes the first transaction on this proxy safer than its cap.

### 6.2 Misconfiguration of a freshly deployed stack

**The risk.** A new stack has many parameters set for the first time, and a wrong value causes loss
even when the code is correct.

**What reduces it.**

- **Nothing is migrated.** The custody contract keeps its bytecode, storage, approvals and positions.
  Exposure comes from a role grant, not from moving funds, so a bad deployment can be reversed by
  revoking one role rather than by recovering assets.
- **The role grant itself is routine.** Spells `20250403`, `20250417`, `20250918`, `20251030`,
  `20251127`, `20260129` and `20260312` each granted unscoped `CONTROLLER` on this exact proxy to
  freshly deployed bytecode and revoked the predecessor. What is new here is that the previous grant
  stays in place, not that a new controller receives one.
- **The four new contracts custody nothing** and hold no privileges outside their own stack.
- **Almost every misconfiguration fails closed**, so the default outcome is that the new controller
  cannot act rather than that it acts wrongly:

| Unset or wrong | Result |
| --- | --- |
| Rate limit key (`maxAmount == 0`) | `RateLimits/zero-maxAmount` |
| Tick limits | `UniswapV4Facet/tickLimits-not-set` |
| `maxSlippage` | `UniswapV4Facet/max-slippage-not-set` |
| CCTP domain parameters | `CCTPFacet/domain-not-configured` |
| Selector not wired | `CallSelectorNotWired` |
| Protocol addresses | Cannot be misconfigured post deploy. `permit2`, `positionManager`, `router`, `cctp`, `usdc` and `hook` are all bytecode immutables |

**What remains.** A handful of parameters fail open, meaning a plausible wrong value causes loss
rather than a revert. These need explicit per value review at spell time:

| Parameter | Wrong value | Consequence |
| --- | --- | --- |
| CCTP `mintRecipient` | valid but wrong `bytes32` | USDC bridged to the wrong address, irrecoverable. The highest consequence value in the deployment |
| `maxFeeCapRate` per domain | too generous | recurring fee leak on every transfer, invisible to rate limits, which meter amount and not fee |
| Tick limits, `maxSlippage`, `priceRatio` | too permissive | real impermanent loss or slippage, inside the cap |
| Aggregate versus per asset denomination | see 4.3 | a legacy swap value copied for a 6 decimal token is wrong by `1e12` |
| Key written to the wrong `RateLimits` instance | either | the intended controller stays blocked, or a live budget is created on the wrong instance. Nothing reverts at spell time |

Two mitigations cover this. First, stage 1 caps are set small enough that a wrong value is survivable
while it is discovered. Second, the spell test harness must be extended before the grant, because it
is currently instance scoped: `_getRateLimitKeys` in
`spark-spells/src/test-harness/SparkLiquidityLayerTests.sol` filters rate limit events to the single
`ctx.rateLimits`, so orphan key detection and the maximum and slope sanity bounds would skip the new
instance and the harness would pass green with no coverage of it. Constructor argument and admin
cardinality assertions for a new PAU stack also do not exist yet and need writing. Both are
prerequisites in stage 0, not follow ups.

### 6.3 A facet reaches further than its own integration

**The risk.** Facets run by `delegatecall` from the Controller. An ERC-7201 storage namespace is a
layout convention, not a sandbox. A buggy or malicious facet can read the proxy address from shared
storage and issue arbitrary `doCall`, `doCallWithValue` or `doDelegateCall`, and can write any
Controller storage slot including the dispatch table. Per facet blast radius is therefore the whole
`ALMProxy` balance, not the assets that facet manages. Rate limits do not bound this case either,
because a compromised facet chooses which key to decrement and can decline to decrement anything.

**What reduces it.**

1. **Arming a facet needs two governance bodies.** Sky can register a facet on the Beacon but cannot
   make it live; `SPARK_PROXY` can sync but cannot invent a config. `fallback()` consults only the
   local dispatch table, so neither body acting alone can make new code reachable.
2. **The sync is pinned.** Per 5.1, the spell reads `Beacon.getConfig(id)` and requires the facet
   address and wire count to match hardcoded audited values in the same transaction, so what goes
   live is the reviewed facet and not whatever the Beacon happens to hold at execution time.
3. **The reachable surface is small and fully enumerable**: 7 value moving functions across 3 facets
   per the table in 2.1, each `nonReentrant`, role gated, rate limited and pointed at a bytecode
   immutable.
4. **A compromised allocator cannot widen it**, per 2.3. CCTP is the clearest case: the allocator
   supplies only amount, destination domain and fee cap rate, while `mintRecipient` is governance set
   per domain, `destinationCaller` and `minFinalityThreshold` are bytecode constants, and `maxFee` is
   clamped to a governance band. That is tighter than legacy CCTP v1 for the same operation.
5. **Each facet has its own kill switch.** `removeIntegrations([id])` deletes that facet's dispatches,
   is callable by `SPARK_PROXY` alone with no Sky coordination, and leaves the other facets and the
   legacy controller untouched. The legacy controller has no equivalent beyond zeroing rate limits.
6. **The change is smaller than the upgrades it replaces.** A `MainnetController` upgrade swapped 40+
   integrations at once into bytecode with no production history and the same unscoped proxy
   authority. Onboarding two or three facets onto a controller whose dispatch table starts empty is a
   strictly smaller version of the same operation.

**What remains.** Every added facet is another code path holding full proxy authority, bounded by
review and audit coverage rather than by architecture, which is why facets are onboarded one stage at
a time. `DualPoolFacet` is not yet in an audited release and must be merged, audited, deployed and
Beacon registered before it is in scope, which is why it is last in the ramp. `CCTPFacet` has no
production usage yet and adds a dependency on Circle's CCTP v2 attestation infrastructure that legacy
v1 does not have.

### 6.4 Two controllers on one `ALMProxy`

**The risk.** Two controllers custody the same account, so state that one assumes to be stable can be
changed by the other. There are three places this could bite: shared rate limit accounting, balance
measurements taken around a call, and total capacity across the pair.

**Shared rate limit accounting is removed entirely.** `CONTROLLER` on `RateLimits` is not key scoped,
so a shared instance would let either controller write any of the other's budgets, and several key
derivations are byte identical across the two codebases. The dedicated instance in 4.1 makes that
authority empty in both directions: the Diamond Controller holds no role on the legacy instance and
the legacy controller holds no role on the new one. This is the double spend and cross access concern,
and it does not exist in this configuration.

**Balance measurements are protected by hook policy.** The reentrancy guard lives in Controller
storage because facets `delegatecall` in, and the shared `ALMProxy` has no guard of its own
([ARCHITECTURE.md](./ARCHITECTURE.md#multi-controller-topology-single-almproxy)). Several facet
functions snapshot proxy balances around a call and use the delta for rate limit accounting:

| Site | Arithmetic | If the balance moves mid-operation |
| --- | --- | --- |
| `UniswapV4Facet._increaseLiquidity` | `_clampedSub(start, end)` | under-decrements the deposit limit on inflow, over-decrements on outflow |
| `UniswapV4Facet._decreaseLiquidity` | `end - start`, unclamped | over-decrements the withdraw limit on inflow, reverts on outflow |
| `UniswapV4Facet._swap` | `end - start`, unclamped | inflates the measured output so the facet's own slippage check passes spuriously, though the Universal Router's `amountOutMin` in the calldata still binds |
| `DualPoolFacet._addLiquidity` / `_removeLiquidity` | same clamped and unclamped pattern | same |

The snapshots are taken and consumed **inside one transaction**, so a separately submitted legacy
transaction cannot land between them and transaction ordering alone cannot reach this. The only way in
is control yielding inside the Diamond Controller's own call frame, which means a Uniswap V4 hook on
an onboarded pool, or the DualPool hook, calling back. That is closed by policy rather than by code:
onboard only pools whose hooks are zero, or reviewed and non-upgradeable; keep pool onboarding a
governance action and never allocator discretion; keep the DualPool hook governance owned. Stage 2
makes recorded hook review a gate for every added pool for exactly this reason. The residual outcomes
are also bounded even if a hook did get through, since the withdraw path reverts, the deposit path
mis-accounts a limit while staying inside the cap, and the swap path is still bound by the router's own
minimum.

**Capacity is reconciled in spell review, then removed.** For any operation both controllers can
perform, real capacity is the sum of the two budgets rather than either one. The control is procedural:
any spell touching one side states the other side's current value, so the approved number is always
the sum. It then goes away on its own, since stage 4 zeroes the legacy CCTP v1 keys and stage 6 can
zero the legacy UniV4 keys per pool. Both are only possible because the instances are separate.

**Emergency response needs two transactions.** Stopping allocator activity across the pair means
`MainnetController.removeRelayer` on the legacy side and `AdministeredAgent.removeActor` per actor on
the Diamond side, per 3.1. Nothing consolidates these, so it is handled operationally: the runbook
documents both paths and stage 0 requires the full stop to be rehearsed on a fork with a recorded wall
clock time before the grant is made.

---

## 7. Rollback

Reverting the upgrade is a single governance transaction:

```solidity
ALMProxy.revokeRole(CONTROLLER, diamondController);
newRateLimits.revokeRole(CONTROLLER, diamondController);
```

The legacy `RateLimits` needs no cleanup, because the Diamond Controller was never granted a role on
it. After revocation the Diamond PAU Controller retains no authority.

Two caveats:

- Open Uniswap V4 positions minted through it remain owned by the `ALMProxy`, and because the legacy
  controller uses the same position manager and asserts `positionManager.ownerOf(tokenId) == proxy`,
  they can be unwound through the legacy controller. Confirm this against the actual position NFTs
  before relying on it.
- In-flight CCTP v2 messages are unaffected by revocation and will still mint at the destination.
  Revocation prevents new transfers, it does not recall pending ones.

---

## 8. Open questions

**1. Who holds the `AdministeredAgent` grantor role?**
Leave it unassigned so only the agent admin (`SPARK_PROXY`) can add actors, which makes adding a
relayer a governance action; or assign it to an ops multisig for faster rotation.

---

## References

- [ARCHITECTURE.md](./ARCHITECTURE.md), Multi-Controller Topology section
- [SECURITY.md](./SECURITY.md), Beacon governance surface
- [THREAT_MODEL.md](./THREAT_MODEL.md)
- [RATE_LIMITS.md](./RATE_LIMITS.md)
- [BEACON.md](./BEACON.md)
- [UNIV3_UNIV4_COMPARISON.md](./UNIV3_UNIV4_COMPARISON.md)
- `src/facets/uniswap-v4/UniswapV4Facet.sol`, `src/facets/cctp/CCTPFacet.sol`
- `test/mainnet-fork/ForkTestBase.t.sol`, `_wireUniswapV4Facet` and `_wireCCTPFacet` for the canonical
  selector wiring
- `spark-alm-controller/src/libraries/UniswapV4Lib.sol` and `src/libraries/CCTPLib.sol` for the legacy
  implementations
- [sky-pau-registry](https://github.com/sky-ecosystem/sky-pau-registry/blob/master/src/Ethereum.sol),
  canonical addresses for the Diamond PAU core and facets
- [pau-assemblers](https://github.com/sky-ecosystem/pau-assemblers), `DefaultPAUAssembler` docs and the
  Sky Core review checklist
