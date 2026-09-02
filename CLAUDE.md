# diamond-pau

Diamond-pattern PAU (Protocol Allocation Unit): a Controller delegatecalls immutable
facets that move funds held by an ALMProxy, bounded by rate limits and role-based
access control. Facets are the only extension surface and the primary security
boundary — a facet executes with the Controller's full authority over custody.

## If you are working on a facet (new or modified)

Everything is codified — do not infer conventions from partial reading:

- `standards/FACET_RULEBOOK.md` — the single source of truth for facet requirements.
  Rule IDs (G/S/A/R/V/ST/E/D/T/X) are cited by scripts, CI, and reviewers.
- `standards/ADVERSARIAL_REVIEW.md` — the review methodology CI applies.
- Skills: `/facet-spec` → `/facet-scaffold` → `/facet-audit` → `/facet-preflight`
  (spec-first is a hard gate: `specs/<dir>.md` must be merged before facet code).
- `./checks/run_all.sh` — the deterministic gate, identical locally and in CI.
- Reference implementations: `src/facets/erc4626/` (golden),
  `src/facets/transfer-asset/` (minimal), `src/facets/wrap-proxy-eth/`
  (constructor/immutables). Reference tests: `test/mainnet-fork/Aave.t.sol`.

## Repo commands

- Build: `forge build --sizes ./src`
- Test: `FOUNDRY_PROFILE=ci forge test` (fork tests need `MAINNET_RPC_URL`,
  `BASE_RPC_URL`, `AVALANCHE_RPC_URL`)
- Facet gate: `./checks/run_all.sh [--skip-coverage]`
- Gate self-test: `./checks/fixtures/test_gate.sh`

## Security-critical invariants (never weaken in any change)

- Facets run via delegatecall from the Controller — facet code IS the Controller.
- All value moves through `ALMProxy.doCall`/`doCallWithValue`; `doDelegateCall` is
  never used by facets.
- Every outbound value path has an enforcing `_decreaseRateLimit` on a key derived
  from the parameters it acts on; approvals are zeroed in the same call.
- Facet storage is ERC-7201 namespaced (`sky.pau.storage.<Name>Facet.v1`) — slot
  constants are recomputed by `checks/check_storage.py`, never trusted.
- Architecture docs: `docs/ARCHITECTURE.md`, `docs/THREAT_MODEL.md`,
  `docs/SECURITY.md`, `docs/RATE_LIMITS.md`.
