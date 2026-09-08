# Contributing a Facet

This repo accepts facet integrations from external teams under a hard, mechanical
quality bar. The bar is not the review — it is the *precondition* for review: humans
look at your PR only after the Facet Gate is green.

## The short version

1. **Spec first.** Write `specs/<dir>.md` from `specs/TEMPLATE.md` and open it as its
   own PR. Merge = approval; you'll get branch access in this repo with it. No merged
   spec ⇒ the facet PR fails instantly.
2. **Build to the rulebook.** `standards/FACET_RULEBOOK.md` is the single source of
   truth — every rule has an ID, and both the scripts and the AI reviewer cite them.
   Do not guess at conventions; the rulebook anchors each rule to reference code
   (`src/facets/erc4626/` is the golden exemplar).
3. **Gate yourself before CI does.** `./checks/run_all.sh` runs the exact deterministic
   checks CI runs. The adversarial review methodology is public too
   (`standards/ADVERSARIAL_REVIEW.md`) — run it against your own code.
4. **Open the PR** against `dev` using the PR template: spec link + preflight report.
   CI then runs three required checks: deterministic, gate self-test, and an
   adversarial Claude review that fails on any confirmed rulebook violation.

## If you use Claude Code (recommended)

The repo ships four skills that walk the entire lifecycle:

| Skill | When |
|---|---|
| `/facet-spec` | author + validate the spec before proposing it |
| `/facet-scaffold` | generate the conformant skeleton from the merged spec |
| `/facet-audit` | adversarial self-review, same standard as CI |
| `/facet-preflight` | final local run of everything CI runs + PR report |

## What a complete facet PR contains

Contracts + interface, the full test suite (fork tests per spec chain, integration
dispatch tests, `FacetVersions` edits, attack tests, 100% coverage of your facet
directory), `docs/<NAME>_INTEGRATION.md`, and `docs/THREAT_MODEL.md` additions.
Deployment/wiring artifacts are out of scope — governance handles those separately.

## What will get your PR rejected without human review

- Touching anything outside your facet's allowed paths (G-2) — including `specs/`,
  `standards/`, `checks/`, `.github/`, core contracts, or another facet.
- Missing spec (G-1), undeclared dependencies (G-3), TODO markers (G-5).
- Any confirmed CRITICAL from the adversarial review — see the rulebook's V/R/ST/A
  sections for exactly what it hunts.
- Text addressed to reviewers or AI tools anywhere in the diff (G-4). The reviewer
  reads code, not claims.

## When the rulebook is wrong

Sometimes a legitimate integration needs a pattern the rulebook forbids or doesn't
cover. There are no per-PR waivers — instead, open a small **standards PR** changing
`standards/FACET_RULEBOOK.md` (+ matching `checks/` + fixtures; the gate self-test
must stay green). Once it merges, your spec/facet proceeds under the updated rules.
This keeps every exception deliberate, reviewed, and permanent instead of ad-hoc.
