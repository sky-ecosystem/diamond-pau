#!/usr/bin/env python3
"""V-1, V-4(DET), V-7, V-8, A-1, A-3, T-5: forbidden-pattern lint.

Usage:
  check_forbidden.py --base <ref>            # git mode: scan facet dirs + changed tests
  check_forbidden.py --source <path> [...]   # harness mode: scan given files
"""

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import (REPO_ROOT, Finding, changed_files, facet_dirs, report,
                 solidity_functions, strip_comments)

# (rule, severity, regex, message) applied to comment-stripped facet sources.
SOURCE_BANS = [
    ("V-1", "CRITICAL", r"doDelegateCall",
     "doDelegateCall executes arbitrary code in the fund-custody proxy — absolute ban"),
    ("V-8", "CRITICAL", r"\bselfdestruct\b", "selfdestruct is banned"),
    ("V-8", "CRITICAL", r"\.delegatecall\s*\(", "raw delegatecall is banned"),
    ("V-8", "CRITICAL", r"\btx\.origin\b", "tx.origin is banned"),
    ("V-8", "CRITICAL", r"\bcreate2?\s*\(", "in-facet contract deployment is banned"),
    ("V-8", "CRITICAL", r"\bnew\s+[A-Z]\w*\s*\(",
     "in-facet contract deployment (`new C(...)`) is banned"),
    ("V-8", "CRITICAL", r"\becrecover\b",
     "signature-gating of entry points is banned — auth is onlyRole"),
    ("A-3", "CRITICAL", r"\b(grantRole|revokeRole|renounceRole|setRoleAdmin)\s*\(",
     "facets never touch the ACL"),
]

# Facet-only bans with legitimate uses in UUPS modules (S-9 review governs modules):
# modules import OZ upgradeable from lib/, define their own ACL, and WEETHModule
# legitimately declares receive() for EtherFi withdrawal claims.
FACET_ONLY_BANS = [
    ("A-1", "CRITICAL", r'keccak256\s*\(\s*"[^"]*ROLE[^"]*"\s*\)',
     "facets may not define new roles — only DEFAULT_ADMIN_ROLE and ALLOCATOR_ROLE exist"),
    ("A-1", "CRITICAL", r"\bmodifier\s+\w+",
     "facets may not define modifiers — auth comes from the base Facet"),
    ("V-7", "CRITICAL", r"^\s*(receive\s*\(\s*\)|fallback\s*\()",
     "facets must not declare receive()/fallback()"),
    ("S-6", "HIGH", r'import\s+[^;]*"[^"]*(\.\./)+lib/',
     "facets do not import from lib/ — declare a minimal I<X>Like shim instead"),
]

TEST_BANS = [
    ("T-5", "CRITICAL",
     r"vm\.(start)?[Pp]rank\s*\(\s*address\s*\(\s*\w*[Cc]ontroller\w*\s*\)",
     "pranking the controller bypasses the auth model under test"),
    ("T-5", "CRITICAL",
     r"vm\.(store|etch)\s*\(\s*address\s*\(\s*(accessControls|rateLimits|almProxy|"
     r"\w*[Cc]ontroller\w*)\b",
     "rewriting system-contract state/code in tests hides real behavior"),
    ("T-5", "CRITICAL", r"vm\.ffi\s*\(", "ffi is banned in this repo's tests"),
    ("T-5", "CRITICAL", r'ffi\s*=\s*true', "enabling ffi is banned"),
]

ROLE_ALLOWLIST = ('"ALLOCATOR_ROLE"',)


def scan_source(path, text, findings, is_module):
    stripped = strip_comments(text)
    for rule, sev, pattern, msg in SOURCE_BANS:
        for m in re.finditer(pattern, stripped, re.M):
            line = stripped[: m.start()].count("\n") + 1
            findings.append(Finding(rule, sev, f"{path}:{line}", msg))
    if not is_module:
        for rule, sev, pattern, msg in FACET_ONLY_BANS:
            for m in re.finditer(pattern, stripped, re.M):
                if rule == "A-1" and any(a in m.group(0) for a in ROLE_ALLOWLIST):
                    continue
                line = stripped[: m.start()].count("\n") + 1
                findings.append(Finding(rule, sev, f"{path}:{line}", msg))

    # V-8: assembly allowed only as the exact ERC-7201 storage accessor idiom.
    for m in re.finditer(r"assembly\s*(\([^)]*\))?\s*\{([^}]*)\}", stripped):
        body = m.group(2).strip()
        if not re.fullmatch(r"\$\.slot\s*:=\s*\w*STORAGE_LOCATION\w*", body):
            line = stripped[: m.start()].count("\n") + 1
            findings.append(Finding(
                "V-8", "CRITICAL", f"{path}:{line}",
                "assembly is allowed only for the ERC-7201 storage accessor idiom"))

    # V-4 (DET): every non-zero approval has a same-function zero reset. Covers direct
    # ApproveLib.approve calls AND internal `_approve*` wrapper call-sites (curve /
    # uniswap-v3 / uniswap-v4 style). The wrapper body itself is exempt — its amount is
    # a passthrough parameter; the pairing obligation sits with its callers.
    approve_call = re.compile(
        r"(?:ApproveLib\.approve|_approve\w*)\s*\(\s*([^;]*?)\)\s*;")
    for fn_name, body in solidity_functions(stripped):
        if re.fullmatch(r"_approve\w*", fn_name):
            continue
        calls = []
        for a in approve_call.finditer(body):
            args = [x.strip() for x in a.group(1).split(",")]
            if len(args) < 2:
                continue
            calls.append((a.start(), tuple(args[:-1]), args[-1]))
        for start, head, amount in calls:
            if amount == "0":
                continue
            if not any(h == head and amt == "0" and s > start
                       for s, h, amt in calls):
                line = stripped[: stripped.find(body) + start].count("\n") + 1
                findings.append(Finding(
                    "V-4", "CRITICAL", f"{path}:{line}",
                    f"`{fn_name}` sets a non-zero approval ({', '.join(head)}) without "
                    f"a same-function zero reset — standing approvals from the proxy "
                    f"are exfiltration primitives (spec-declared exceptions require a "
                    f"rulebook exception entry, not silence)"))


def scan_test(path, text, findings):
    stripped = strip_comments(text)
    for rule, sev, pattern, msg in TEST_BANS:
        for m in re.finditer(pattern, stripped):
            # The one sanctioned vm.store: the house reentrancy-test idiom
            # (_setControllerEntered / test_*_reentrancy) writing the guard slot.
            line_end = stripped.find("\n", m.start())
            line_text = stripped[m.start(): line_end if line_end != -1 else None]
            if "vm.store" in m.group(0) and "REENTRANCY_GUARD" in line_text:
                continue
            line = stripped[: m.start()].count("\n") + 1
            findings.append(Finding(rule, sev, f"{path}:{line}", msg))


def load_exceptions():
    path = Path(__file__).parent / "exceptions.json"
    if not path.exists():
        return set()
    data = json.loads(path.read_text())
    return {(e["rule"], e["path"]) for e in data.get("exceptions", [])}


def apply_exceptions(findings):
    exceptions = load_exceptions()
    kept = []
    for f in findings:
        bare = f.path.split(":")[0]
        if (f.rule, bare) in exceptions:
            continue
        kept.append(f)
    return kept


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--source", nargs="*", default=[])
    ap.add_argument("--test", nargs="*", default=[])
    args = ap.parse_args()

    findings = []
    if args.source or args.test:
        for path in args.source:
            name = Path(path).name
            is_module = name.endswith(("Module.sol", "Buffer.sol"))
            scan_source(path, Path(path).read_text(), findings, is_module)
        for path in args.test:
            scan_test(path, Path(path).read_text(), findings)
    else:
        files = changed_files(args.base)
        dirs = facet_dirs(files)
        if not dirs:
            print("✓ check_forbidden: no facet directories touched — gate not applicable")
            return 0
        for d in dirs:
            for f in sorted((REPO_ROOT / "src" / "facets" / d).glob("*.sol")):
                is_module = f.name.endswith(("Module.sol", "Buffer.sol"))
                scan_source(f.relative_to(REPO_ROOT).as_posix(), f.read_text(),
                            findings, is_module)
        for path in files:
            if path.startswith("test/") and path.endswith(".sol"):
                p = REPO_ROOT / path
                if p.exists():
                    scan_test(path, p.read_text(), findings)

    return report(apply_exceptions(findings), "check_forbidden")


if __name__ == "__main__":
    sys.exit(main())
