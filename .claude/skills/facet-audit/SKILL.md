---
name: facet-audit
description: Adversarial self-review of a facet against the rulebook — the same standard the CI gate applies. Use before opening or updating a facet PR, after significant implementation changes, or when asked to review facet code in this repo.
---

# Facet Audit

Runs the identical review the CI gate will run, so nothing in CI is a surprise. This is
not a linter pass — the deterministic rules are `checks/run_all.sh`'s job. This skill is
the judgment layer: fund-exit enumeration, privilege reachability, spec-vs-code,
protocol assumptions, and test cross-examination.

## Procedure

1. Load, in this order, and follow them exactly:
   - `standards/FACET_RULEBOOK.md` — the rules and rule IDs.
   - `standards/ADVERSARIAL_REVIEW.md` — the six-step methodology and evidence rules.
2. Establish the diff: `git diff $(git merge-base HEAD origin/dev)...HEAD`.
3. Execute Steps 0–6 of the methodology **against your own code as if it were hostile**.
   The temptation to skip steps because "I just wrote this and know it's fine" is
   exactly how the historical bugs shipped (dangling approvals PR #189, missing
   slippage PR #191, missing refills PR #204 review) — authors don't see their own
   blind spots, procedures do.
4. Where the methodology says to run things, run them: `forge build`, `forge test
   --match-contract <Name>`, targeted reads of the external protocol's deployed code on
   the pinned fork block.
5. Calibrate with the judgment seeds: `checks/fixtures/judgment/` contains planted
   violations that deterministic checks cannot see (S90 unbounded outbound gate-check,
   S91 key/target mismatch, S92 mock-echo test). If your review process wouldn't have
   caught those three, redo the review — the CI reviewer is validated against them.

## Output

A findings report in the PR-ready format:

```
## Facet audit — <Name>Facet @ <commit>

### Confirmed violations   (must be fixed before preflight)
- [<SEVERITY>] <rule-id> `<file>:<line>` — <one-sentence defect> 
  Path: <inputs → code → effect>

### Notes                   (unconfirmed suspicions, spec ambiguities)
- ...

### Attestations
- Fund exits enumerated: <n> paths, each bounded by: <keys>
- Spec diff: implements spec exactly / deviations: <list>
- T-3 coverage map: <function> → <tests present/missing>
```

Fix every confirmed violation and re-run until the violations section is empty, then
run `/facet-preflight`. Do not argue with a rule in the PR — if a rule is wrong for a
legitimate new pattern, that is a rulebook-change PR (see FACET_RULEBOOK.md preamble).
