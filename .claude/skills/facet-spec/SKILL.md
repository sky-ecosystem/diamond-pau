---
name: facet-spec
description: Write and validate an integration spec for a new PAU facet (specs/<dir>.md) — the required first step before any facet code. Use when starting a new facet integration, proposing one, or checking whether a draft spec is complete enough to submit for approval.
---

# Facet Spec

The spec is the contract between the integrating team and the repo maintainers: facet
code is later reviewed *against it* (rulebook D-3/X-3), and its frontmatter drives the
deterministic gate (chains → required test files, dependencies → allowed lib additions,
integration_doc → doc-drift checks). **A facet PR without a previously merged spec fails
the gate instantly (G-1)** — the spec is its own small PR, approved and merged first.

## Procedure

1. Read `standards/FACET_RULEBOOK.md` (at minimum: G, R, V, ST sections) so the spec
   promises something the rulebook can accept.
2. Copy `specs/TEMPLATE.md` to `specs/<dir>.md` where `<dir>` is the facet's
   kebab-case directory name (must match `src/facets/<dir>/` exactly).
3. Fill every section. While filling, study the closest existing integration:
   - simple rate-limited venue → `specs/` examples + `src/facets/erc4626/`
   - constructor/immutables → `src/facets/wrap-proxy-eth/`
   - auxiliary UUPS module → `src/facets/weeth/`, `src/facets/otc/`
4. Self-validate before submitting — the spec is complete when you can answer YES to:
   - Frontmatter parses and is exact: `facet`, `dir`, `chains` (only
     mainnet/base/avalanche), `integration_doc`, `dependencies` (empty list if none).
   - Every facet function is listed with its full signature, role
     (ALLOCATOR/DEFAULT_ADMIN), rate-limit key + `make*Key` composition in the house
     (asset, origin) order, and refill behavior on the reverse leg.
   - Every path value can leave custody is enumerated, each with its bounding decrease
     key. Gate-check-only functions are justified as value-returning (R-5).
   - Standing approvals, opaque `bytes` parameters, and admin knobs are each either
     absent or explicitly declared with rationale (V-2/V-4).
   - The external protocol's trust assumptions are stated against the house constraints
     (non-rebasing ≥6-dec tokens, donation/inflation surface, seeding requirements,
     oracle assumptions, cross-chain destination configuration).
   - Dependencies name the exact upstream repo + commit to be pinned, or the list is
     empty. New `RateLimitHelpers` `make*Key` shapes are declared here too.
5. Sanity-check mechanically: the gate parses frontmatter with
   `checks/lib.py:parse_spec_frontmatter` — run
   `python3 -c "from checks.lib import parse_spec_frontmatter; print(parse_spec_frontmatter(open('specs/<dir>.md').read()))"`
   and confirm the dict contains what you meant.
6. Open the spec as a standalone PR touching only `specs/<dir>.md`. Approval = merge.
   After it merges, `/facet-scaffold` builds the skeleton from it.

## Hard rules

- Do not promise anything the rulebook forbids (e.g. a function that sends value to an
  allocator-supplied recipient without a key derived from it). If the integration
  genuinely needs a pattern the rulebook lacks, the spec PR must be preceded by a
  rulebook-change PR — flag this to the maintainers instead of hiding it in prose.
- Scope is binding in both directions: the facet may implement nothing beyond the spec,
  and everything in the spec. Write the spec you intend to build exactly.
