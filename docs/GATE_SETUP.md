# Facet Gate — Activation Guide (repo admins)

Everything in this repo's facet gate ships inert until two admin actions are taken.
Total effort: ~10 minutes. Until both are done, the gate runs but does not block.

## 1. Add the API key (2 min)

Settings → Secrets and variables → Actions → **New repository secret**:

- `ANTHROPIC_API_KEY` — an Anthropic API key (the adversarial-review job uses the
  `anthropics/claude-code-action@v1` action). Consider a spend limit on the key;
  a typical facet review is a few dollars, and the job caps itself at 50 turns.

The deterministic job needs the RPC secrets the existing CI already has
(`MAINNET_RPC_URL`, `BASE_RPC_URL`) plus **`AVALANCHE_RPC_URL`, which existing CI
does not set** — add it while you're here (avalanche fork tests currently ride on
foundry's default public endpoint, which is flaky).

## 2. Make the checks required (3 min)

Settings → Branches → branch protection rule for `dev` (and `master` if facet PRs can
ever target it) → **Require status checks to pass** → add:

- `Facet Gate / Deterministic checks`
- `Facet Gate / Gate self-test (seeded defects)`
- `Facet Gate / Adversarial review`

Notes:
- Non-facet PRs: the deterministic job passes vacuously and the adversarial review is
  skipped (a skipped check satisfies branch protection). Maintainer PRs aren't slowed.
- Fork PRs never receive `ANTHROPIC_API_KEY` (the workflow uses the `pull_request`
  trigger precisely for this), so the review can't run on them and they cannot merge.
  This is intentional: **external teams get a branch in this repo once their spec is
  approved** (Settings → Collaborators → write access, or a `facet/*` branch-scoped
  ruleset). Spec approval is the trust decision; branch access is its implementation.

## 3. Operating model (context, not action)

- The rulebook (`standards/FACET_RULEBOOK.md`) is owned by whoever maintains this repo.
  Every change to `standards/` or `checks/` must keep
  `./checks/fixtures/test_gate.sh` green — CI runs it on every PR, which forces rules,
  scripts, and seeded fixtures to evolve together (this is the anti-rot mechanism).
- No per-PR waivers exist by design. Pattern changes land as rulebook PRs first.
  Grandfathered deviations live in `checks/exceptions.json`, scoped rule+file, with
  rationale — extend it only via standards PRs.
- Humans review only green PRs. The gate's findings comment (posted on the PR) is the
  starting point; `notes` in the verdict are the unconfirmed suspicions worth a look.
- Open item at handoff: T-7's 100%-coverage bar was validated mechanically but not yet
  against a full fork run (local archive-RPC limits). The first facet PR — or a dry
  run of `python3 checks/check_coverage.py --base origin/dev~1` on a facet-touching
  commit in CI — confirms it. If the golden facet can't reach 100% branch, tune the
  bar via a standards PR (`--min-branch` flag in `checks/run_all.sh` + rulebook T-7).

## 4. Cost & noise controls

- The review job is path-gated (runs only when `src/facets/**` changes) and
  concurrency-capped per PR (new pushes cancel stale runs).
- `--max-turns 50` bounds each review; the structured-output schema prevents
  free-form verdicts.
- If a review job flakes (API outage), re-run the single job from the Checks tab.
