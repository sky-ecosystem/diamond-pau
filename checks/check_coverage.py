#!/usr/bin/env python3
"""T-7: 100% line and branch coverage on every touched facet directory.

Runs `forge coverage` scoped to the facet's own test contracts and parses the lcov
output for the facet's source files. Repo-wide coverage stays governed by ci.yml;
this check is only about the new/changed facet.

Usage:
  check_coverage.py --base <ref> [--min-line 100] [--min-branch 100]
  check_coverage.py --lcov <file> --facet-dir <dir> [...]   # harness/offline mode
"""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from lib import REPO_ROOT, Finding, changed_files, facet_dirs, facet_name, report


def parse_lcov(text, prefix):
    """Return {path: {lines: (hit, total), branches: (hit, total)}} for files under prefix."""
    stats = {}
    current, da_hit, da_total, br_hit, br_total = None, 0, 0, 0, 0
    for line in text.splitlines():
        if line.startswith("SF:"):
            current = line[3:].strip()
            da_hit = da_total = br_hit = br_total = 0
        elif line.startswith("DA:") and current:
            da_total += 1
            if int(line.split(",")[1]) > 0:
                da_hit += 1
        elif line.startswith("BRDA:") and current:
            br_total += 1
            taken = line.rsplit(",", 1)[1].strip()
            if taken not in ("-", "0"):
                br_hit += 1
        elif line == "end_of_record" and current:
            if current.startswith(prefix):
                stats[current] = {"lines": (da_hit, da_total),
                                  "branches": (br_hit, br_total)}
            current = None
    return stats


def run_forge_coverage(match_contract):
    out_file = Path(tempfile.mkstemp(suffix=".lcov")[1])
    cmd = ["forge", "coverage", "--report", "lcov", "--report-file", str(out_file),
           "--match-contract", match_contract]
    print(f"  running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout[-4000:])
        sys.stderr.write(result.stderr[-4000:])
        raise SystemExit("forge coverage failed")
    return out_file.read_text()


def check_facet(lcov_text, d, min_line, min_branch, findings):
    prefix = f"src/facets/{d}/"
    stats = parse_lcov(lcov_text, prefix)
    if not stats:
        findings.append(Finding("T-7", "HIGH", prefix,
                                "no coverage records — facet tests exercise nothing here"))
        return
    for path, s in sorted(stats.items()):
        lh, lt = s["lines"]
        bh, bt = s["branches"]
        line_pct = 100.0 * lh / lt if lt else 100.0
        branch_pct = 100.0 * bh / bt if bt else 100.0
        if line_pct < min_line:
            findings.append(Finding(
                "T-7", "HIGH", path,
                f"line coverage {lh}/{lt} = {line_pct:.1f}% (< {min_line}%) — "
                f"uncovered lines in a facet are unreviewed authority"))
        if branch_pct < min_branch:
            findings.append(Finding(
                "T-7", "HIGH", path,
                f"branch coverage {bh}/{bt} = {branch_pct:.1f}% (< {min_branch}%)"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--lcov")
    ap.add_argument("--facet-dir", nargs="*", default=[])
    ap.add_argument("--min-line", type=float, default=100.0)
    ap.add_argument("--min-branch", type=float, default=100.0)
    args = ap.parse_args()

    findings = []
    if args.lcov:
        text = Path(args.lcov).read_text()
        for d in args.facet_dir:
            check_facet(text, d, args.min_line, args.min_branch, findings)
    else:
        files = changed_files(args.base)
        dirs = facet_dirs(files)
        if not dirs:
            print("✓ check_coverage: no facet directories touched — gate not applicable")
            return 0
        for d in dirs:
            name = facet_name(d)
            if not name:
                continue  # missing impl is check_structure's finding
            lcov = run_forge_coverage(name)
            check_facet(lcov, d, args.min_line, args.min_branch, findings)

    return report(findings, "check_coverage")


if __name__ == "__main__":
    sys.exit(main())
