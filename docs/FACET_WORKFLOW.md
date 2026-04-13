# AI-Assisted Facet Development Workflow

This document describes the end-to-end process for building a new protocol integration facet — from business requirements to a PR ready for engineer review.

The goal: an engineer fills out a spec template, an AI coding agent implements and tests it, a security agent reviews the diff, and the engineer merges. No vibe coding. No untested code. No security shortcuts.

---

## Roles

| Role | Who | Responsibility |
|---|---|---|
| **Spec author** | Engineer / Lucas | Fills out the requirements template |
| **Coding agent** | Claude Code (ACP) | Implements facet, interface, tests — iterates until green |
| **Security reviewer** | Sparky | Reviews diff before PR is opened |
| **Merge owner** | Engineer | Code review, final approval, merge |

---

## Step 1 — Fill Out the Requirements Template

Copy `docs/FACET_INTEGRATION_TEMPLATE.md` to a new branch:

```bash
git checkout -b feat/<protocol>-facet
cp docs/FACET_INTEGRATION_TEMPLATE.md docs/integrations/<Protocol>Integration.md
```

Fill in every section:

- Protocol name, facet name, integration ID
- Which chains it deploys to
- External contract addresses (must reference `spark-address-registry` — no hardcoding)
- Constructor immutables
- Per-facet storage fields
- Rate limit constants and key types
- Per-operation step-by-step behavior (relayer functions)
- Admin setter behavior
- View functions
- Events table
- Wiring table (Controller selector → Facet selector, for every function)
- External protocol interface (paste the relevant Solidity)
- Known edge cases and risks (fee-on-transfer, slippage, reentrancy callbacks, etc.)
- PR scope checklist

**The template is the single source of truth.** The more precise it is — especially edge cases — the less the coding agent has to guess.

Commit the completed template to the branch.

---

## Step 2 — Spawn the Coding Agent

From OpenClaw (Sparky), spawn a Claude Code session pointed at the branch:

```
Implement the facet described in docs/integrations/<Protocol>Integration.md.

Follow docs/FACET_STANDARDS.md for all implementation rules.
Follow docs/FACET_TESTING.md for all test requirements.

Files to create:
- src/facets/<protocol>/<Protocol>Facet.sol
- src/facets/<protocol>/I<Protocol>Facet.sol
- test/integration/facets/<Protocol>Facet.t.sol
- test/mainnet-fork/<Protocol>.t.sol (if mainnet integration)
- test/base-fork/<Protocol>.t.sol (if Base integration)

Run forge build and forge test after each implementation step.
Iterate until all tests pass and the build is clean.
Do not open a PR — stop when tests are green and ping Sparky for security review.
```

The agent reads the template, implements the facet in TDD style (interface → stub → tests red → implementation → tests green), and iterates until `forge build` and `forge test` are clean.

---

## Step 3 — Security Review

Once the coding agent reports tests are green, tag Sparky for a security review of the diff:

```
Review the diff on branch feat/<protocol>-facet before we open a PR.
```

Sparky checks:
- Access control on every function (`nonReentrant` + `onlyRole`, correct order)
- Rate limit calls on every relayer function that moves value
- ERC-7201 slot uniqueness — no collision with existing facets
- Zero-address guards on all admin setters and constructor args
- `ApproveLib` used (not inline approvals)
- All external calls go through `IALMProxy.doCall`
- No hardcoded protocol addresses (constructor immutables only)
- Events emitted after state changes, not before
- No new findings against `ethskills/security.md` patterns

If issues are found, Sparky files them as comments. The coding agent fixes. Repeat until clean.

---

## Step 4 — Open the PR

Once Sparky signs off, the coding agent opens the PR:

```bash
gh pr create \
  --title "feat: <Protocol>Facet (DEV-XXXX)" \
  --body "Implements <Protocol>Facet per docs/integrations/<Protocol>Integration.md.

## What
- New facet for <one sentence>
- Chains: <list>
- Rate limits: <list>

## Testing
- Integration tests: test/integration/facets/<Protocol>Facet.t.sol
- Fork tests: test/mainnet-fork/<Protocol>.t.sol

## Security
- Reviewed by Sparky (security agent) — no findings
- ERC-7201 slot verified unique
- All rate limit paths covered

## Checklist
- [ ] forge build clean
- [ ] All integration tests pass
- [ ] All admin setter tests present (reentrancy, unauthorized, input validation, happy path)
- [ ] All relayer tests present (reentrancy, unauthorized, rate limit, happy path)
- [ ] No changes to existing contracts
" \
  --draft
```

PR is opened as draft. Assign to the merge owner.

---

## PR Size Limit

**Target: ≤ 500 lines changed (additions + deletions) in `src/` and `test/` combined.**

This is a hard guideline, not a suggestion. Small PRs are easier to review, easier to reason about security, and easier to roll back.

If an implementation exceeds 500 lines, split it:
- **PR 1** — interface + facet stub (compiles, no logic)
- **PR 2** — relayer functions + their tests
- **PR 3** — admin setters + view functions + their tests

Never split tests from the code they test. Each PR must be self-contained: it compiles, its tests pass, and it does not depend on a subsequent PR to be correct.

If you're unsure whether a split makes sense, default to smaller. An engineer can always merge two small PRs faster than reviewing one large one.

---

## Step 5 — Complete the Pre-Launch Security Checklist

Before the PR can move out of draft, the author must complete `docs/FACET_PRELAUNCH_CHECKLIST.md` for this integration and commit it to `docs/integrations/<Protocol>Integration.md` alongside the requirements spec.

Every question needs a documented answer — not just "yes." The point is explicit reasoning, not checkbox theater. Sparky's security review covers the same ground but the checklist forces the spec author to think through risks before implementation, not after.

Key questions the checklist covers:
- If the relayer is compromised, can funds exit? How much, how fast?
- If the admin is compromised, what's the worst-case misconfiguration?
- If the external protocol is paused or exploited, are funds stuck?
- Is every value-moving function covered by a rate limit?
- Is the ERC-7201 slot provably unique?
- Are all constructor args sourced from the registry?
- Do all tests pass (integration + fork)?

---

## Step 6 — Engineer Review and Merge

The merge owner:
1. Reviews the diff against `FACET_STANDARDS.md` — spot-check structure, naming, patterns
2. Reads the test file — verify coverage is real, not superficial
3. Checks the wiring table in the template matches the actual `Wire[]` array in the test setup
4. Removes draft status and merges

Deployment scripts and on-chain wiring (Beacon registration, Controller `updateIntegrations`, state migration) are handled separately — they are NOT part of this PR.

---

## Reference Docs

| Doc | Purpose |
|---|---|
| `docs/FACET_STANDARDS.md` | Implementation rules — structure, storage, access control, rate limits, events |
| `docs/FACET_TESTING.md` | Test coverage requirements — every required test pattern |
| `docs/FACET_INTEGRATION_TEMPLATE.md` | Blank spec template — copy and fill out for each new integration |
| `docs/integrations/` | Completed spec files for each integration (create this dir as you go) |

---

## What This Flow Prevents

- **Vibe coding** — the template forces explicit spec before implementation
- **Missing tests** — the testing standard mandates every test category; the coding agent can't skip
- **Security regressions** — Sparky reviews every diff before it's a PR, not after
- **Hardcoded addresses** — the template requires registry references; standards prohibit constants
- **Storage collisions** — ERC-7201 slot is computed and verified in review
- **Untested rate limits** — rate limit tests are mandatory in `FACET_TESTING.md`
