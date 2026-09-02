#!/usr/bin/env python3
"""S-1..S-4, S-7(DET), S-8, E-1, E-3, D-1(DET), D-2(DET), T-1, G-5: structure & naming.

Usage:
  check_structure.py --base <ref>                  # git mode (full repo-level checks)
  check_structure.py --facet-file <path> [...]     # content rules only (harness mode)
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import (REPO_ROOT, Finding, changed_files, facet_dirs, facet_name,
                 parse_spec_frontmatter, read_at_base, report, strip_comments)

CHAIN_TEST_DIR = {
    "mainnet": "test/mainnet-fork",
    "base": "test/base-fork",
    "avalanche": "test/avalanche-fork",
}


def check_source_content(path, text, findings, kind):
    """Content rules that apply to a single facet source file.
    kind: 'impl' | 'interface' | 'other'"""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "// SPDX-License-Identifier: AGPL-3.0-or-later":
        findings.append(Finding("S-2", "MEDIUM", path,
                                "line 1 must be the AGPL-3.0-or-later SPDX header"))
    if len(lines) < 2 or lines[1].strip() != "pragma solidity ^0.8.34;":
        findings.append(Finding("S-2", "MEDIUM", path,
                                "line 2 must be `pragma solidity ^0.8.34;`"))

    stripped = strip_comments(text)

    for marker in ("TODO", "FIXME", "XXX"):
        if re.search(rf"\b{marker}\b", text):
            findings.append(Finding("G-5", "HIGH", path,
                                    f"{marker} marker — facet PRs ship complete"))
    if re.search(r"\bconsole2?\b", stripped):
        findings.append(Finding("G-5", "HIGH", path, "console logging in submission"))

    if kind == "impl":
        name = Path(path).stem  # <Name>Facet
        base = name[:-len("Facet")]
        decl = re.search(r"contract\s+" + re.escape(name) + r"\s+is\s+([^{]+)\{", stripped)
        if not decl:
            findings.append(Finding("S-3", "HIGH", path,
                                    f"missing `contract {name} is I{name}, Facet` declaration"))
        else:
            parents = [p.strip() for p in decl.group(1).split(",")]
            if parents != [f"I{name}", "Facet"]:
                findings.append(Finding(
                    "S-3", "HIGH", path,
                    f"inheritance must be exactly `I{name}, Facet` (found: {', '.join(parents)})"))
        if not re.search(r'string\s+public\s+constant\s+override\s+VERSION\s*=\s*"1\.0\.0"\s*;',
                         stripped):
            findings.append(Finding(
                "S-4", "MEDIUM", path,
                'missing `string public constant override VERSION = "1.0.0";`'))
        if re.search(r"^\s*event\s+\w+", stripped, re.M):
            findings.append(Finding("E-1", "MEDIUM", path,
                                    "events must be declared in the interface, not the implementation"))
        for m in re.finditer(r"^\s*error\s+(\w+)", stripped, re.M):
            findings.append(Finding(
                "E-3", "MEDIUM", path,
                f"custom error `{m.group(1)}` — facet validation uses require-strings "
                f'`"{name}/<kebab-reason>"`'))
        for m in re.finditer(r"require\s*\(", stripped):
            pass  # message-prefix conformance is enforced by review (E-3 JUD half)
        _ = base

    if kind == "interface":
        name = Path(path).stem  # I<Name>Facet
        if not re.search(r"interface\s+" + re.escape(name) + r"\s+is\s+IFacet\s*\{", stripped):
            findings.append(Finding("S-3", "HIGH", path,
                                    f"missing `interface {name} is IFacet` declaration"))


def repo_level_checks(base, files, findings):
    dirs = facet_dirs(files)
    for d in dirs:
        facet_dir = REPO_ROOT / "src" / "facets" / d
        name = facet_name(d)
        if name is None:
            findings.append(Finding("S-1", "HIGH", f"src/facets/{d}/",
                                    "no <Name>Facet.sol implementation found"))
            continue
        impl = f"src/facets/{d}/{name}Facet.sol"
        iface = f"src/facets/{d}/I{name}Facet.sol"
        if not (facet_dir / f"I{name}Facet.sol").exists():
            findings.append(Finding("S-1", "HIGH", iface, "missing paired interface"))

        # Content rules for every .sol in the facet dir.
        for f in sorted(facet_dir.glob("*.sol")):
            rel = f.relative_to(REPO_ROOT).as_posix()
            kind = ("impl" if f.name == f"{name}Facet.sol"
                    else "interface" if f.name == f"I{name}Facet.sol" else "other")
            check_source_content(rel, f.read_text(), findings, kind)

        impl_text = (facet_dir / f"{name}Facet.sol").read_text() \
            if (facet_dir / f"{name}Facet.sol").exists() else ""

        # T-1: FacetVersions.t.sol — the four required edits.
        fv_path = REPO_ROOT / "test" / "unit" / "FacetVersions.t.sol"
        fv = fv_path.read_text() if fv_path.exists() else ""
        checks = [
            (rf"import\s*\{{\s*{name}Facet\s*\}}", "import"),
            (rf"{name}Facet\s+internal\s+(\w+)", "state variable"),
            (rf"=\s*new\s+{name}Facet\s*\(", "instantiation in setUp"),
        ]
        var_match = re.search(rf"{name}Facet\s+internal\s+(\w+)\s*;", fv)
        for pattern, what in checks:
            if not re.search(pattern, fv):
                findings.append(Finding("T-1", "HIGH", "test/unit/FacetVersions.t.sol",
                                        f"missing {what} for {name}Facet"))
        if var_match:
            var = var_match.group(1)
            if not re.search(rf'assertEq\(\s*{var}\.VERSION\(\)\s*,\s*"1\.0\.0"\s*\)', fv):
                findings.append(Finding(
                    "T-1", "HIGH", "test/unit/FacetVersions.t.sol",
                    f'missing `assertEq({var}.VERSION(), "1.0.0")` assertion'))

        # T-1: per-chain fork tests + integration test, driven by the spec.
        spec = read_at_base(base, f"specs/{d}.md") or ""
        meta = parse_spec_frontmatter(spec)
        chains = meta.get("chains", ["mainnet"]) or ["mainnet"]
        for chain in chains:
            tdir = CHAIN_TEST_DIR.get(chain)
            if tdir is None:
                findings.append(Finding("T-1", "HIGH", f"specs/{d}.md",
                                        f"spec names unknown chain '{chain}'"))
                continue
            if not (REPO_ROOT / tdir / f"{name}.t.sol").exists():
                findings.append(Finding("T-1", "HIGH", f"{tdir}/{name}.t.sol",
                                        f"missing fork test file for spec chain '{chain}'"))
            fork_base = REPO_ROOT / tdir / "ForkTestBase.t.sol"
            if fork_base.exists() and f"{name}Facet" not in fork_base.read_text():
                findings.append(Finding("T-1", "HIGH", f"{tdir}/ForkTestBase.t.sol",
                                        f"{name}Facet not wired in the {chain} fork test base"))
        if not (REPO_ROOT / "test" / "integration" / "facets" / f"{name}Facet.t.sol").exists():
            findings.append(Finding("T-1", "HIGH",
                                    f"test/integration/facets/{name}Facet.t.sol",
                                    "missing integration dispatch test"))

        # D-1 (DET): integration doc present, non-trivial, no key/event drift.
        doc_name = meta.get("integration_doc", f"{name.upper()}_INTEGRATION.md")
        doc_path = REPO_ROOT / "docs" / doc_name
        if not doc_path.exists():
            findings.append(Finding("D-1", "HIGH", f"docs/{doc_name}",
                                    "missing integration doc"))
        else:
            doc = doc_path.read_text()
            if len(doc) < 1500:
                findings.append(Finding("D-1", "HIGH", f"docs/{doc_name}",
                                        "integration doc is too thin to describe an integration"))
            for lit in re.findall(r'keccak256\("(LIMIT_\w+)"\)', impl_text):
                if lit not in doc:
                    findings.append(Finding("D-1", "HIGH", f"docs/{doc_name}",
                                            f"rate-limit key `{lit}` undocumented (doc drift)"))
            for ev in set(re.findall(r"\bemit\s+(\w+)\s*\(", strip_comments(impl_text))):
                if ev not in doc:
                    findings.append(Finding("D-1", "HIGH", f"docs/{doc_name}",
                                            f"event `{ev}` undocumented (doc drift)"))

        # D-1: THREAT_MODEL.md must gain the new surface.
        if "docs/THREAT_MODEL.md" not in files:
            findings.append(Finding("D-1", "HIGH", "docs/THREAT_MODEL.md",
                                    "facet PR must extend the threat model with the new "
                                    "external-protocol surface"))

        # D-2 (DET): implementation externals carry @inheritdoc.
        ext_count = len(re.findall(r"\b(?:external|public)\b", strip_comments(impl_text)))
        inherit_count = len(re.findall(r"@inheritdoc", impl_text))
        if ext_count and inherit_count == 0:
            findings.append(Finding("D-2", "MEDIUM", impl,
                                    "no @inheritdoc on implementation members — NatSpec "
                                    "belongs on the interface, @inheritdoc on the impl"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--facet-file", nargs="*", default=[])
    args = ap.parse_args()

    findings = []
    if args.facet_file:
        for path in args.facet_file:
            p = Path(path)
            kind = ("interface" if p.name.startswith("I") and p.name.endswith("Facet.sol")
                    else "impl" if p.name.endswith("Facet.sol") else "other")
            check_source_content(path, p.read_text(), findings, kind)
    else:
        files = changed_files(args.base)
        if not facet_dirs(files):
            print("✓ check_structure: no facet directories touched — gate not applicable")
            return 0
        repo_level_checks(args.base, files, findings)

    return report(findings, "check_structure")


if __name__ == "__main__":
    sys.exit(main())
