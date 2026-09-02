---
facet: <Name>Facet
dir: <kebab-dir>
chains: [mainnet]
integration_doc: <NAME>_INTEGRATION.md
dependencies: []
---

<!--
Copy to specs/<dir>.md. The frontmatter is machine-read by checks/ (G-1, G-3, T-1,
D-1) — keys are exact:
  facet            PascalCase contract name, e.g. ERC4626Facet
  dir              directory under src/facets/, e.g. erc4626
  chains           subset of [mainnet, base, avalanche]; drives required fork tests
  integration_doc  filename under docs/ this facet documents itself in
  dependencies     lib/ submodule names this facet may add (empty list if none)

Approval = this file merging to dev via its own PR. The facet PR is later reviewed
against this document (rulebook D-3/X-3): everything here is binding, in both
directions. See .claude/skills/facet-spec for the authoring procedure.
-->

# <Name> Integration Spec

## Summary

<What this facet does, which external protocol it integrates, and why (the capital
allocation purpose). 2–4 sentences.>

## External protocol

- **Protocol:** <name, version>
- **Contracts touched:** <address + chain for each, with a one-line role>
- **Audited/battle-tested status:** <links>
- **Trust assumptions:** <what must be true of this protocol for funds to be safe —
  upgradability/admin powers, oracle usage, pausability, rebasing/fee-on-transfer
  behavior, donation/inflation surface>
- **House-constraint check:** tokens are non-rebasing, ≥6 decimals, standard ERC-20;
  no oracle reliance on 1:1 stablecoin legs; seeding requirements: <describe or n/a>

## Functions

One block per external function. Everything here is checked against the code.

### `<signature, e.g. deposit(address vault, uint256 amount, uint256 minSharesOut)>`

- **Role:** ALLOCATOR_ROLE | DEFAULT_ADMIN_ROLE
- **Value direction:** outbound (leaves custody) | returning (to proxy) | config
- **Rate limit:** key constant `LIMIT_<...>`, derivation `make<...>Key(_LIMIT_<...>,
  <params in (asset, origin) order>)`; enforcing decrease of <amount>
- **Refill:** `_tryIncreaseRateLimit(<opposite key>, <amount>)` | none, because <reason>
- **Loss bounds:** <minOut/maxIn params + admin caps (maxSlippage/maxExchangeRate)>
- **External calls:** <target.function via doCall/doCallWithValue; receiver is proxy>
- **Zero-amount semantics:** <allowed/forbidden, matching the protocol's documented
  behavior — cite it>

## Fund-exit map

Enumerate every path value can leave custody through this facet, each with its
bounding key. This is the table the adversarial reviewer verifies first (X-1).

| # | Path | Destination | Bounded by |
|---|------|-------------|------------|
| 1 | <doCall deposit> | <vault, proxy receives shares> | <LIMIT_..., per (asset, vault)> |

## Storage & constructor

- **ERC-7201 storage fields:** <admin parameters only, or "none">
- **Immutables:** <list + why fixed at deploy, or "none">
- **Auxiliary module:** <none | name + why a UUPS module is unavoidable (S-9)>

## Standing approvals & declared exceptions

<None, or each exception with rationale — e.g. async RFQ mint with no synchronous leg
to zero against. Silence here means the gate treats any standing approval as V-4.>

## Dependencies

<None, or: exact upstream repo URL + commit to pin, why it must be vendored rather
than shimmed (S-6), and any new RateLimitHelpers make*Key shape needed.>

## Attack surface (drives T-4 required tests)

- **Mutable third-party reads feeding keys/checks:** <e.g. vault.asset() — requires a
  `test_attack_assetChanged_*`>
- **Async/multi-step state a rogue allocator could grief:** <describe or n/a>
- **Value-manipulation surface (donation/inflation/rounding):** <describe or n/a>

## Operational requirements

<Deployment-order constraints, seeding, rate-limit configuration guidance for
governance, monitoring hooks. Deploy scripts are out of scope for the facet PR.>
