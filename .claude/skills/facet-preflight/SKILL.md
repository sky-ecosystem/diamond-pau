---
name: facet-preflight
description: Final gate before opening a facet PR — runs everything CI will run (deterministic checks, gate self-test, build, tests, coverage, adversarial audit) and produces the preflight report the PR template requires. Use when a facet is believed complete.
---

# Facet Preflight

CI's `Facet Gate` is a hard required check; a PR that fails it wastes a round-trip.
Preflight runs the same gates locally, in the same order, and assembles the report the
PR template asks for. **Green preflight ⇒ green CI** (the scripts are literally the
same; the only difference is CI's pinned environment).

## Procedure

Run each step; stop and fix on first failure:

1. **Deterministic gate** — `./checks/run_all.sh`
   (full run including coverage; needs `MAINNET_RPC_URL` etc. exported for fork tests).
2. **Gate self-test** — `./checks/fixtures/test_gate.sh`
   (proves your checkout's checks are intact; if this fails you've modified `checks/`
   or `standards/` — facet PRs may not (G-2)).
3. **Build & full test suite** —
   `forge build --sizes ./src && FOUNDRY_PROFILE=ci forge test`
   (the existing CI workflow runs this too; a facet PR must not break anything).
4. **Adversarial audit** — `/facet-audit`, until confirmed-violations is empty.
5. **Docs freshness** — re-read `docs/<NAME>_INTEGRATION.md` against the final code:
   keys, signatures, events, refill matrix (doc drift was the most-repeated PR #204
   finding class).

## Output

Append to the PR description:

```
## Preflight report

- checks/run_all.sh: PASS (base: <merge-base sha>)
- gate self-test: 23/23
- forge build --sizes: PASS
- forge test (ci profile): <n> passed, 0 failed
- coverage src/facets/<dir>/: 100.0% lines, 100.0% branches
- /facet-audit: 0 confirmed violations, <n> notes (attached below)
- spec: specs/<dir>.md @ <merged commit>

<audit report>
```

Numbers, not adjectives. The CI reviewer treats the report as claims and re-derives
everything (X-6) — its purpose is to make *you* run the gates, not to persuade anyone.
