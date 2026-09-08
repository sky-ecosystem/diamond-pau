#!/usr/bin/env python3
"""ST-1, ST-2: ERC-7201 storage discipline.

Recomputes every declared storage slot from its namespace string (via `cast keccak`,
so the real keccak256 — no trust in the hardcoded constant), verifies the namespace
matches the contract name, and checks collisions against reserved slots and every
other declared slot in the tree. Also flags contract-level state variables declared
outside the FacetStorage pattern.

Usage:
  check_storage.py --base <ref>            # git mode
  check_storage.py --source <path> [...]   # harness mode
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import (REPO_ROOT, RESERVED_SLOTS, Finding, changed_files, facet_dirs,
                 report, strip_comments)


def keccak(data):
    """keccak256 via foundry's cast; data is str (utf8) or bytes."""
    arg = data if isinstance(data, str) else "0x" + data.hex()
    out = subprocess.run(["cast", "keccak", arg], capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit(f"cast keccak failed: {out.stderr}")
    return out.stdout.strip()


def erc7201_slot(namespace):
    k1 = int(keccak(namespace), 16)
    k2 = int(keccak((k1 - 1).to_bytes(32, "big")), 16)
    return f"0x{k2 & ~0xff:064x}"


def declared_slots_in_tree():
    """All hardcoded *STORAGE_LOCATION constants under src/ (for uniqueness checks)."""
    slots = {}
    for f in (REPO_ROOT / "src").rglob("*.sol"):
        text = strip_comments(f.read_text())
        for m in re.finditer(r"(\w*STORAGE_LOCATION\w*)\s*=\s*(0x[0-9a-fA-F]{64})", text):
            slots.setdefault(m.group(2).lower(), []).append(
                f.relative_to(REPO_ROOT).as_posix())
    return slots


def scan_file(path, text, findings, tree_slots):
    stripped = strip_comments(text)
    contract = re.search(r"\b(?:contract|abstract\s+contract)\s+(\w+)", stripped)
    if not contract:
        return
    cname = contract.group(1)

    namespaces = re.findall(r"@custom:storage-location\s+erc7201:([\w.\-]+)", text)
    constants = re.findall(r"STORAGE_LOCATION\s*=\s*(0x[0-9a-fA-F]{64})", stripped)

    if namespaces or constants:
        if len(namespaces) != 1 or len(constants) != 1:
            findings.append(Finding(
                "ST-1", "CRITICAL", path,
                f"expected exactly one ERC-7201 namespace + one slot constant "
                f"(found {len(namespaces)} / {len(constants)})"))
            return
        ns, declared = namespaces[0], constants[0].lower()

        expected_ns = (f"sky.pau.storage.{cname}.v1" if cname.endswith("Facet")
                       else f"sky.pau.storage.{cname}.v1")
        if not re.fullmatch(rf"sky\.pau\.storage\.{re.escape(cname)}\.v\d+", ns):
            findings.append(Finding(
                "ST-1", "CRITICAL", path,
                f"namespace `{ns}` must be `{expected_ns}` — a borrowed namespace "
                f"aliases another contract's storage"))

        computed = erc7201_slot(ns).lower()
        if computed != declared:
            findings.append(Finding(
                "ST-1", "CRITICAL", path,
                f"slot constant {declared} does not match keccak-derived slot "
                f"{computed} for namespace `{ns}` — recompute or explain nothing"))

        if declared in RESERVED_SLOTS:
            findings.append(Finding(
                "ST-2", "CRITICAL", path,
                f"slot collides with reserved {RESERVED_SLOTS[declared]} slot"))
        owners = [o for o in tree_slots.get(declared, []) if o != path]
        if owners:
            findings.append(Finding(
                "ST-2", "CRITICAL", path,
                f"slot already declared by {', '.join(owners)}"))

        if not re.search(r"function\s+_getFacetStorage\s*\(", stripped) and \
           cname.endswith("Facet"):
            findings.append(Finding(
                "ST-1", "CRITICAL", path,
                "storage declared without the standard _getFacetStorage() accessor"))

    # ST-1: no sequential state variables (constants/immutables excepted).
    if cname.endswith("Facet"):
        for m in re.finditer(
            r"^\s{4}(mapping\s*\(|uint\d*\s|int\d*\s|address\s|bool\s|bytes\d*\s|"
            r"string\s)(?![^;\n]*\b(?:constant|immutable)\b)[^;\n(]*;",
            stripped, re.M,
        ):
            line = stripped[: m.start()].count("\n") + 1
            findings.append(Finding(
                "ST-1", "CRITICAL", f"{path}:{line}",
                "contract-level state variable outside the ERC-7201 FacetStorage "
                "pattern — facets use namespaced storage only"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--source", nargs="*", default=[])
    args = ap.parse_args()

    findings = []
    tree_slots = declared_slots_in_tree()
    if args.source:
        for path in args.source:
            scan_file(path, Path(path).read_text(), findings, tree_slots)
    else:
        files = changed_files(args.base)
        dirs = facet_dirs(files)
        if not dirs:
            print("✓ check_storage: no facet directories touched — gate not applicable")
            return 0
        for d in dirs:
            for f in sorted((REPO_ROOT / "src" / "facets" / d).glob("*.sol")):
                scan_file(f.relative_to(REPO_ROOT).as_posix(), f.read_text(),
                          findings, tree_slots)

    return report(findings, "check_storage")


if __name__ == "__main__":
    sys.exit(main())
