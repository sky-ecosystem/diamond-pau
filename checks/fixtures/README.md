# Gate Fixtures

Seeded-defect harness for the facet gate. `test_gate.sh` runs in CI on every PR
(`Facet Gate / Gate self-test`) and locally via `/facet-preflight`. Its contract:

- **`clean/`** — a compact facet + interface + test snippet satisfying every
  deterministic rule. Every check must pass it. If a check change flags the clean
  fixture, the check has a false positive; if a rulebook change makes the clean
  fixture non-conformant, update the fixture *in the same PR*.
- **`seeded/S01..S14`** — one planted violation each, mapped to an expected rule ID.
  Every check change must still catch every seed. Adding a rule to the rulebook?
  Add its seed here in the same PR — a DET rule without a seed is unproven.
- **`manifests/M01..M06`** — synthetic diff manifests exercising the scope rules
  (G-1/G-2/G-3) without git state.
- **`judgment/S90..S92`** — violations *invisible by construction* to the
  deterministic layer: S90 unbounded outbound behind a gate-check (R-3/R-5), S91
  rate-limit key derived from a constant while acting on a variable target (R-2),
  S92 a mock-echo test that asserts nothing real (T-6/X-5). They validate the
  adversarial reviewer: any change to `standards/ADVERSARIAL_REVIEW.md` or the CI
  review prompt should be re-checked by running a review against these three files
  plus `clean/` (expected: three confirmed findings with those rule IDs, zero on
  clean). They are intentionally NOT wired into `test_gate.sh` — they cost an LLM
  run and exist to keep the judgment layer honest, not the scripts.

None of these files are compiled by forge (they live outside `src/` and `test/`).
The `.sol` extension is for tooling/highlighting only.
