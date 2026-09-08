# Facet Integration Specs

**Spec-first is a hard gate.** A facet PR is only reviewable if `specs/<dir>.md`
already exists on `dev` at the PR's merge-base — i.e. the spec was submitted as its own
PR, reviewed, and merged *before* facet code was written (`FACET_RULEBOOK.md` G-1). The
CI gate enforces this mechanically and reviews the facet code *against* the approved
spec (D-3/X-3): the facet may implement nothing more and nothing less.

## Lifecycle

1. **Author** — copy `TEMPLATE.md` to `specs/<dir>.md` and fill it
   (`/facet-spec` walks through this).
2. **Propose** — open a PR touching only that spec file.
3. **Approve** — repo maintainers review scope, security assumptions, and rulebook
   fit. Merge = approval. If the integration needs a pattern the rulebook forbids,
   a rulebook-change PR precedes the spec (no per-PR waivers, ever).
4. **Build** — `/facet-scaffold` generates the conformant skeleton from the merged
   spec; the facet PR follows, gated by `checks/` + the adversarial CI review.
5. **Amend** — scope changes during development go back through a spec PR first.
   A facet PR may never touch `specs/` (G-1).

## Frontmatter is load-bearing

`facet`, `dir`, `chains`, `integration_doc`, `dependencies` are machine-read by the
deterministic gate (required test files per chain, allowed `lib/` additions, doc-drift
checks). Typos here surface as gate failures on the facet PR.
