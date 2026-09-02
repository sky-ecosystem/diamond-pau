#!/usr/bin/env python3
"""G-1, G-2, G-3(DET), G-5(partial): spec-first, diff scope, dependency declaration.

Usage:
  check_diff_scope.py --base <ref>          # git mode
  check_diff_scope.py --manifest <file>     # harness mode
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import (Finding, changed_files, exists_at_base, facet_dirs, facet_name,
                 load_manifest, parse_spec_frontmatter, read_at_base, report)


def full_access_patterns(d, name):
    upper = name.upper()
    return [
        rf"^src/facets/{re.escape(d)}/",
        rf"^test/mainnet-fork/{re.escape(name)}\w*\.t\.sol$",
        rf"^test/base-fork/{re.escape(name)}\w*\.t\.sol$",
        rf"^test/avalanche-fork/{re.escape(name)}\w*\.t\.sol$",
        rf"^test/integration/facets/{re.escape(name)}Facet\.t\.sol$",
        rf"^test/unit/{re.escape(name)}\w*\.t\.sol$",
        rf"^docs/{re.escape(upper)}\w*_INTEGRATION\.md$",
    ]


ADDITIVE_ONLY = [
    "test/unit/FacetVersions.t.sol",
    "test/mainnet-fork/ForkTestBase.t.sol",
    "test/base-fork/ForkTestBase.t.sol",
    "test/avalanche-fork/ForkTestBase.t.sol",
    "test/integration/TestBase.t.sol",
    "test/interfaces/IMainnetControllerFull.sol",
    "test/interfaces/IForeignControllerFull.sol",
    "test/mainnet-fork/Attacks.t.sol",
    "docs/THREAT_MODEL.md",
    "src/libraries/RateLimitHelpers.sol",
]

# Dependency plumbing, allowed only when the spec declares the dependency (G-3).
DEPENDENCY_PATHS = [r"^\.gitmodules$", r"^foundry\.toml$", r"^foundry\.lock$", r"^lib/"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--manifest")
    args = ap.parse_args()

    if args.manifest:
        manifest = load_manifest(args.manifest)
        files = manifest["files"]
        base_specs = set(manifest.get("base_specs", []))
        spec_text = manifest.get("spec_text", {})
        names = manifest.get("facet_names", {})

        def spec_exists(d):
            return f"specs/{d}.md" in base_specs

        def spec_body(d):
            return spec_text.get(d, "")

        def name_of(d):
            return names.get(d)
    else:
        files = changed_files(args.base)

        def spec_exists(d):
            return exists_at_base(args.base, f"specs/{d}.md")

        def spec_body(d):
            return read_at_base(args.base, f"specs/{d}.md") or ""

        def name_of(d):
            return facet_name(d)

    findings = []
    dirs = facet_dirs(files)

    if not dirs:
        print("✓ check_diff_scope: no facet directories touched — gate not applicable")
        return 0

    # G-1: spec approved (merged) before code; specs/ untouched by this PR.
    integration_docs = set()
    for d in dirs:
        if not spec_exists(d):
            findings.append(Finding(
                "G-1", "CRITICAL", f"specs/{d}.md",
                "no approved spec at merge-base — spec PRs must merge before facet PRs"))
        else:
            meta = parse_spec_frontmatter(spec_body(d))
            doc = meta.get("integration_doc")
            if doc:
                integration_docs.add(doc)
    for path in files:
        if path.startswith("specs/"):
            findings.append(Finding(
                "G-1", "CRITICAL", path,
                "facet PRs must not add or modify specs — spec changes are their own PR"))

    # G-3: dependency additions must be declared in the spec.
    declared_deps = set()
    for d in dirs:
        for dep in parse_spec_frontmatter(spec_body(d)).get("dependencies", []) or []:
            declared_deps.add(dep)

    # G-2: every changed path must be allowed.
    allowed_full = []
    for d in dirs:
        name = name_of(d)
        if name:
            allowed_full.extend(full_access_patterns(d, name))
        else:
            allowed_full.append(rf"^src/facets/{re.escape(d)}/")

    for path, info in files.items():
        if any(re.match(p, path) for p in allowed_full):
            continue
        if path in ADDITIVE_ONLY:
            if info.get("deleted", 0) > 0:
                findings.append(Finding(
                    "G-2", "CRITICAL", path,
                    f"shared file allows additions only; diff deletes/modifies "
                    f"{info['deleted']} line(s)"))
            continue
        # Integration doc named by spec frontmatter (covers shared docs like
        # NFAT_INTEGRATION.md spanning multiple facets).
        if path.startswith("docs/") and path[len("docs/"):] in integration_docs:
            continue
        if any(re.match(p, path) for p in DEPENDENCY_PATHS):
            dep_name = path.split("/", 1)[1].split("/")[0] if path.startswith("lib/") else None
            if dep_name and dep_name not in declared_deps:
                findings.append(Finding(
                    "G-3", "CRITICAL", path,
                    f"dependency '{dep_name}' not declared in the approved spec's "
                    f"dependencies list"))
            elif not dep_name and not declared_deps:
                findings.append(Finding(
                    "G-3", "CRITICAL", path,
                    "dependency plumbing changed but no spec declares any dependency"))
            continue
        findings.append(Finding(
            "G-2", "CRITICAL", path,
            "outside the allowed path set for a facet PR (see FACET_RULEBOOK.md G-2)"))

    return report(findings, "check_diff_scope")


if __name__ == "__main__":
    sys.exit(main())
