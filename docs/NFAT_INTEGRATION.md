# NFAT Integration

This document describes the NFAT (Non-Fungible Asset Token) integration with the PAU system. It
covers the two facets (`NFATPrimeFacet` and `NFATHaloFacet`), how they map onto the two sides of an
NFAT facility's book, the interest-accrual model used to rate-limit a non-fungible position, and the
two-controller deployment topology that an NFAT facility is expected to run with.

## Overview

An **NFAT facility** (`NFATFacility`) is a lending venue where capital is subscribed in a fungible
gem (e.g. USDS), then crystallised into a **non-fungible position** (an NFAT NFT) representing a
specific tranche of deployed principal. Repayments (principal and interest) accrue against the
tokenId and are later collected by the NFT owner.

**There is a one-to-one relationship between a PAU system and an NFAT facility.** Every facility is
paired with exactly one PAU stack (ALMProxy, RateLimits, and the Controller(s) wiring the NFAT
facets), and that PAU stack serves exactly one facility — neither is shared. This pairing is
concretely expressed on-chain by the facility's `recipient` being set to **that PAU's ALMProxy**, so
all drawn principal flows into the paired PAU's custody. See
[Deployment Topology](#deployment-topology-two-controllers-one-alm) for how that per-facility PAU
stack is structured.

There are two parties, on opposite sides of the book:

- **Primes** — the deployers / lenders of capital. They subscribe gem into the facility, receive
  issued NFATs, and collect repayments.
- **Halo** — the asset originators. They are the counterparty that draws the principal (via
  `issue`) and services it over time (via `repay`).

This split is exactly why there are **two facets**:

| Facet            | Side of book | Purpose                                                         |
| ---------------- | ------------ | -------------------------------------------------------------- |
| `NFATPrimeFacet` | Prime        | subscribe / withdraw / collect — fund and reclaim capital      |
| `NFATHaloFacet`  | Halo         | issue / repayPrincipal / repayInterest — draw and service debt |

`NFATHaloFacet` is the **first facet built for the Halo side** of the PAU system. Everything prior
operates on the Prime/lender side of the book.

It is **not expected** for a single Controller to wire both the Halo and Prime NFAT facets at once —
they represent opposite counterparties — though nothing prevents it technically.

---

## Facility Permissions and the Bud Requirement

`NFATFacility` uses the standard `wards` / `buds` / `cops` auth model:

- `issue` is gated by the `toll` modifier — **only an operator (`bud`) may call it.**
- `repay` is permissionless (anyone can repay a live tokenId).
- `collect` is owner-only (only the NFAT owner can pull collectable balance).

Because the facet executes facility calls through the ALMProxy (via `IALMProxy.doCall`), the
**ALMProxy must be `kiss`-ed as a `bud` on the facility** so that `issue` succeeds. This is an
operational precondition of the Halo integration.

The facility's `recipient` (the destination of gem transferred out on `issue`) is **expected to be
the ALMProxy**, so that drawn principal lands back in PAU custody and the facet can measure it (see
[Measuring by Balance Delta](#measuring-by-balance-delta)).

---

## Why `issue` is Routed Through the ALMProxy

`NFATFacility.issue` could in principle be called by any bud. We deliberately route it through the
PAU (ALMProxy + facet) for two reasons:

1. **Principal recording.** The facet records the drawn principal into its own ERC-7201 storage
   (`Position.principal`) at issue time. This is the basis for all downstream interest accrual and
   repayment accounting — none of which the facility itself tracks.
2. **Rate limiting.** Routing through the facet lets us apply PAU rate limits to issuance and
   repayment, giving governance a throttle over how fast principal can be drawn against and serviced.

### Measuring by Balance Delta

For flows where the gem actually moves through the ALMProxy, the facet sizes the rate-limit
decrement (and the recorded principal) from the **actual ALMProxy balance delta** around the
facility call, rather than trusting the caller-supplied `amount`:

```
balanceBefore = gem.balanceOf(proxy)
ALMProxy.doCall(facility, issue/repay ...)
delta = |gem.balanceOf(proxy) - balanceBefore|
```

This protects against fee-on-transfer, rounding, or partial-fill behaviour: the system always
accounts for what truly entered or left custody. `issue` records `Position.principal = delta` and
decrements the issue rate limit by `delta`; `repayPrincipal` / `repayInterest` decrement their
respective limits by the measured `spent`.

> **Note (`amount == 0`).** `NFATFacility` permits minting with `amount == 0` (it simply skips the
> gem transfer). The Halo facet does **not** special-case this — a zero-principal issue is not an
> expected production flow and the surrounding accounting for it is not fully built out. It is called
> out here as a known, out-of-scope case rather than a supported one.

---

## Rate Limiting a Non-Fungible Position

NFATs are **not fungible** — each tokenId is a distinct position with its own principal, repayment
schedule, and accrued interest. This makes a naive "limit per token" meaningless and a "limit per
unit" impossible at the token layer. The integration solves this in two complementary ways.

### 1. Issue / Repay rate limits (fungible gem flows)

Issuance and repayment move the fungible gem, so those flows are rate-limited on the gem amount:

| Limit                          | Key tuple              | Helper                          |
| ------------------------------ | ---------------------- | ------------------------------- |
| `LIMIT_NFAT_HALO_ISSUE`        | `(facility, gem, to)`  | `makeAddressAddressAddressKey`  |
| `LIMIT_NFAT_HALO_REPAY_PRINCIPAL` | `(facility, gem)`   | `makeAddressAddressKey`         |
| `LIMIT_NFAT_HALO_REPAY_INTEREST`  | `(facility, gem)`   | `makeAddressAddressKey`         |

The `gem` is included in every key so that a facility cannot silently change its gem out from under
a configured limit — switching the gem invalidates the key.

#### `to` as an inbound-actor whitelist

The **issue** limit is additionally keyed on `to` (the NFAT recipient). This is intentional: it
makes the per-`(facility, gem, to)` rate limit double as a **whitelist of inbound actors** for the
facility. `NFATFacility` does ship an `identityNetwork` for exactly this kind of eligibility
gating, but that mechanism is **not yet production-ready**, so for now the issue rate limit serves
as the operative allowlist: only recipients with a configured, non-zero limit can be issued to.

**Every whitelisted `to` is expected to be a Prime.** Constraining issuance to the Prime network is
how we keep drawn principal **inside the Sky system** — an NFAT can only be issued to an address
that has been onboarded (via a configured rate-limit key) as a Prime, so capital cannot leak to an
arbitrary external recipient.

#### Why not a per-tokenId rate limit?

A natural alternative would be to rate-limit each `tokenId` individually. We deliberately do **not**
do this. The `ALLOCATOR_ROLE` on the Controller wired to the Halo facet is expected to be **iterated
on heavily over time** — the issuance authority (and the off-chain attestation/eligibility logic
behind it) is an evolving surface, and it needs the **autonomy to dish out tokenIds** freely without
governance having to pre-register or top up a limit for every new tokenId.

Keying the limit on `(facility, gem, to)` instead of per-tokenId gives that autonomy while still
bounding risk: the allocator can mint as many tokenIds as it needs to a given Prime, but the
**aggregate** principal issued to that `(facility, gem, to)` tuple is still capped by the configured
rate limit. Risk is controlled at the actor level (who can receive, and how much in total), not at
the per-position level (which would otherwise become a governance bottleneck on every issuance).

A per-tokenId limit would also introduce **coordination risk between the configured limit and the
amount the `ALLOCATOR_ROLE` actually issues**. Governance would have to provision a limit for a
specific tokenId in advance, while the allocator independently decides the tokenId and principal at
issuance time — any mismatch (a limit set for the wrong tokenId, or a different principal than was
provisioned) would cause issuance to revert or be silently under/over-constrained. Keying on the
actor side keeps the limit decoupled from the allocator's tokenId/amount choices, so the two never
have to be kept in lockstep.

### 2. Interest accrual via `annualGrowthRate` (the non-fungible part)

Interest owed on a position grows continuously and cannot be expressed as a discrete per-call gem
amount up front. Instead of trying to rate-limit it directly, the facet accrues interest using a
**dynamic annual growth rate**:

- `setAnnualGrowthRate(facility, rate)` (gated on `DEFAULT_ADMIN_ROLE`) sets a per-facility
  `annualGrowthRate`, a 1e18-scaled APR (`1e18 == 100%/year`).
- A facility-wide **cumulative interest index** advances over time:

  ```
  index(now) = index(lastCheckpoint)
             + annualGrowthRate * (now - lastCheckpoint) / 365 days
  ```

- Each position snapshots the index at issue time. When the position is next touched
  (`_checkpointPosition`), the index delta since its snapshot is applied to its outstanding
  principal to accrue `Position.accruedInterest`.

The `annualGrowthRate` is **flexible and at the `DEFAULT_ADMIN`'s discretion**, but in practice it
is expected to track some multiple of the expected yield on the facility's underlying strategy.
Setting the rate checkpoints the facility first, so interest already accrued under the prior rate is
preserved before the new rate takes effect.

---

## Operations

### Issue (draw principal → mint NFAT)

**Function:** `issue(facility, to, tokenId, amount)` — `ALLOCATOR_ROLE`

**Flow:**

1. Resolve `gem` from the facility.
2. Require the position (`facility`, `tokenId`) is not already issued.
3. Checkpoint the facility's interest index.
4. Snapshot the ALMProxy gem balance, then `doCall` `facility.issue(to, tokenId, amount)`. The
   facility decrements `to`'s subscribed deposit, mints the NFAT to `to`, and transfers the drawn
   gem to its `recipient` (expected to be the ALMProxy).
5. Compute `received` = ALMProxy balance delta and record it as `Position.principal`.
6. Snapshot the current interest index into the position.
7. Decrement `LIMIT_NFAT_HALO_ISSUE` keyed `(facility, gem, to)` by `received`.

**Event:** `NFATHaloIssue(facility, to, tokenId, gem, amount)`

### Repay Principal (service drawn principal)

**Function:** `repayPrincipal(facility, tokenId, amount)` — `ALLOCATOR_ROLE`

**Flow:**

1. Require `amount > 0`.
2. Checkpoint the position (advances the facility index and accrues outstanding interest first).
3. Require `amount <= principal - principalRepaid` (cannot overpay principal).
4. `_doFacilityRepay`: approve gem, `doCall` `facility.repay(tokenId, amount)`, reset approval, and
   measure the gem actually spent from the ALMProxy.
5. Increment `Position.principalRepaid` by the measured `spent`.
6. Decrement `LIMIT_NFAT_HALO_REPAY_PRINCIPAL` keyed `(facility, gem)` by `spent`.

**Event:** `NFATHaloRepayPrincipal(facility, gem, tokenId, amount)`

Repaying principal reduces the outstanding balance that future interest accrues on, but it does not
retroactively change interest already accrued and checkpointed.

### Repay Interest (service accrued interest)

**Function:** `repayInterest(facility, tokenId, amount)` — `ALLOCATOR_ROLE`

**Flow:**

1. Require `amount > 0`.
2. Checkpoint the position so `Position.accruedInterest` reflects interest up to the current block.
3. Require `amount <= accruedInterest`.
4. `_doFacilityRepay` as above, measuring the gem actually spent.
5. Decrement `Position.accruedInterest` by the measured `spent`.
6. Decrement `LIMIT_NFAT_HALO_REPAY_INTEREST` keyed `(facility, gem)` by `spent`.

**Event:** `NFATHaloRepayInterest(facility, gem, tokenId, amount)`

Principal and interest are serviced through **separate** entry points and **separate** rate limits.
This keeps the two obligations independently throttleable and independently observable on-chain, and
means interest can continue to be repaid even after principal is fully repaid (the previously
accrued interest is still owed).

### Prime-side operations

`NFATPrimeFacet` exposes the lender-side flows; each measures its rate-limit movement from the
ALMProxy balance delta as well:

| Function                          | Rate limit                      | Notes                                                       |
| --------------------------------- | ------------------------------- | ---------------------------------------------------------- |
| `subscribe(facility, amount, …)`  | `LIMIT_NFAT_PRIME_SUBSCRIBE` ↓  | Funds the facility deposit; sized by gem leaving custody.  |
| `withdraw(facility, amount)`      | `LIMIT_NFAT_PRIME_WITHDRAW` ↓, `SUBSCRIBE` ↑ | Reclaims un-issued deposit; refills the subscribe budget.  |
| `collect(facility, tokenId, amt)` | `LIMIT_NFAT_PRIME_COLLECT` ↓, `SUBSCRIBE` ↑  | Pulls collectable repayments; refills the subscribe budget. |

All three Prime keys are `(facility, gem)` via `makeAddressAddressKey`.

---

## Deployment Topology: Two Controllers, One ALM

An NFAT facility's PAU setup is expected to run with **two Controllers sharing a single ALMProxy and
a single RateLimits**:

```
                       ┌──────────────────────────────┐
                       │           ALMProxy            │  (single custody account)
                       │           RateLimits          │  (single shared limit store)
                       └──────────────┬────────┬───────┘
                                      │        │
              ┌───────────────────────┘        └───────────────────────┐
              ▼                                                         ▼
   ┌────────────────────────┐                          ┌────────────────────────────┐
   │  Halo Controller       │                          │  Operations Controller       │
   │  • NFATHaloFacet       │                          │  • TransferAssetFacet        │
   │    (issue / repay)     │                          │  • PSMFacet                  │
   │                        │                          │  • ERC4626Facet, …           │
   └────────────────────────┘                          └────────────────────────────┘
```

- One Controller wires the **`NFATHaloFacet`** and is responsible solely for NFAT issuance and
  repayment.
- A second Controller wires the **operational facets** needed to actually run the facility's
  treasury — for example `TransferAssetFacet`, `PSMFacet`, and `ERC4626Facet` — for moving,
  swapping, and deploying the gem.

### Why separate the Halo facet from operational facets

The two Controllers are split deliberately to **separate NFAT issuance/repayment permissions from
day-to-day facility operations**:

- These responsibilities are expected to be run by **different teams** — and, in future, possibly
  **different on-chain modules** — than the team operating the facility's treasury.
- The Halo side carries materially more pre-conditions before a call is safe to make: attestations,
  eligibility checks, and other **off-chain coordination** must happen before `issue` or `repay` is
  invoked. Isolating those flows behind their own Controller and role surface keeps that heavier
  approval path away from routine operational actions.

> ### ⚠️ Auditor note: two Controllers rolling up into one ALMProxy + one RateLimits
>
> This topology — **two independent Controllers sharing a single ALMProxy and a single RateLimits
> instance** — is novel relative to the rest of the PAU system, where a Controller is typically
> paired 1:1 with its own ALM stack. The shared rate-limit store means limits configured by one
> Controller's governance surface and limits configured by the other's both draw from the same
> RateLimits state, and both Controllers can move the same custody balance.
>
> We are explicitly flagging this for auditors to scrutinise: role separation across the two
> Controllers, the interaction of their rate-limit keys in shared state, and any cross-Controller
> assumptions about custody. This is intentional design, not an accident of wiring.

---

## Known Limitations / Out of Scope

- **`amount == 0` issuance** is allowed by `NFATFacility` but is not a handled/expected flow in the
  Halo facet (see note above).
- The facility's **`identityNetwork`** eligibility mechanism exists but is **not production-ready**;
  the issue rate limit's `to` keying is the interim allowlist.
- Routing and balance-delta accounting **assume the facility `recipient` is the ALMProxy**; if it is
  not, drawn principal will not land back in custody and the measured `received` will be zero.

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — overall facet architecture and Controller dispatch.
- [RATE_LIMITS.md](./RATE_LIMITS.md) — rate-limit key construction and patterns.
- [BEACON.md](./BEACON.md) — integration wiring and the dispatch lookup.
