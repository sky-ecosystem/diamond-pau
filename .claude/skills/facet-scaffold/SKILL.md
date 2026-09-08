---
name: facet-scaffold
description: Generate a rulebook-conformant skeleton for a new PAU facet from its approved spec — contracts, interface, fork/integration/unit test files, FacetVersions and ForkTestBase wiring, and the integration doc stub. Use after the spec in specs/<dir>.md has been approved and merged.
---

# Facet Scaffold

Generates the complete file set for a facet PR so that structure, naming, and wiring
conform to `standards/FACET_RULEBOOK.md` from the first commit. The scaffold is a
faithful starting point, not a finished facet: every generated body must then be
implemented against the spec, and `/facet-audit` + `/facet-preflight` decide readiness.

## Preconditions

- `specs/<dir>.md` exists on `dev` (merged = approved). If not, stop and use
  `/facet-spec` first — code before spec fails the gate (G-1).
- Read the spec fully; it defines the function list, keys, chains, and dependencies.

## Reference implementations (copy their shape, not their protocol logic)

- Default: `src/facets/erc4626/` — storage, admin setter, allocator ops with
  decrease/try-increase, approve-then-zero, balance-delta, keyed getters.
- Minimal stateless: `src/facets/transfer-asset/`.
- Constructor + immutables: `src/facets/wrap-proxy-eth/`.
- Auxiliary UUPS module (only if the spec declares one): `src/facets/weeth/`,
  `src/facets/otc/`.
- Tests: `test/mainnet-fork/Aave.t.sol` (fullest), `test/mainnet-fork/ERC4626.t.sol`;
  integration dispatch tests: `test/integration/facets/AaveFacet.t.sol`.

## Generate

For facet `<Name>` in `src/facets/<dir>/`:

1. **`I<Name>Facet.sol`** — `interface I<Name>Facet is IFacet`; full NatSpec on every
   member; sections `Events` (alphabetical, `<Name><Action>` naming, subject indexed) →
   `Interactive Functions` → `Variables` → `View/Pure Functions` (S-5, E-1, E-2, D-2).
2. **`<Name>Facet.sol`** — `contract <Name>Facet is I<Name>Facet, Facet`; sections in
   S-5 order; ERC-7201 storage only if the spec declares admin parameters (namespace
   `sky.pau.storage.<Name>Facet.v1` — **derive the slot constant with
   `cast keccak`, never copy one**; `checks/check_storage.py` recomputes it);
   `_LIMIT_*` constants; `VERSION = "1.0.0"`; every external state-changing function
   `nonReentrant onlyRole(...)` with `override` and `/// @inheritdoc`; in-file
   `I<X>Like` shims for the external protocol (no lib imports, S-6); require-strings
   `"<Name>Facet/<kebab-reason>"` (E-3).
3. **Test skeletons**, one per spec chain:
   - `test/<chain>-fork/<Name>.t.sol`: `abstract contract <Name>_TestBase is
     ForkTestBase` (rate-limit config as the chain's governance executor,
     `_getBlock()` override), one `<Controller>_<Name>_<Function>_Tests` contract per
     function, each pre-populated with the full T-3 set as failing stubs:
     `_reentrancy`, `_notAllocator`, `_zeroMaxAmount`, `_rateLimitBoundary`,
     guard boundaries, success (balance deltas on all three domains + event + exact
     decrement + `vm.record()`/`_assertReentrancyGuardWrittenToTwice()`), paired-limit
     variants.
   - `test/integration/facets/<Name>Facet.t.sol`: wiring, admin-setter auth/reentrancy/
     validation, `test_get<Action>RateLimitKey` derivations.
   - Attack-test stubs in `test/mainnet-fork/Attacks.t.sol` (additions only) for every
     mutable third-party read the spec identifies (T-4).
4. **Wiring** (additions only, G-2): each target chain's `ForkTestBase.t.sol` gets a
   `_wire<Name>Facet` block including `IFacet.VERSION.selector`, `beacon.setIntegration`
   wiring, role grants, and rate limits; `test/unit/FacetVersions.t.sol` gets its four
   edits (import, field, instantiation, `assertEq(..., "1.0.0")`).
5. **`docs/<NAME>_INTEGRATION.md`** — stub with the D-1 required sections: protocol +
   trust assumptions, per-function keys and refill matrix, event signatures, operational
   requirements, failure modes. Every `LIMIT_*` string and event name in the code must
   appear here (the gate greps for drift).
6. **Dependencies** — only those the spec declares (G-3): submodule pinned to the
   spec's commit, remapping in `foundry.toml`.

## After generating

Run `forge build` and `./checks/run_all.sh --skip-coverage` immediately — the skeleton
must pass structure/forbidden/storage checks *before* protocol logic goes in. Then
implement, keeping `/facet-audit` in the loop rather than saving review for the end.
