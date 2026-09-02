"""Shared helpers for the deterministic facet-gate checks.

Every check script supports two modes:
  - git mode (CI / local preflight): changed files come from `git diff --base <ref>`
  - manifest mode (harness): changed files come from a JSON manifest, letting
    checks/fixtures/test_gate.sh exercise every rule without touching git state.

Checks report findings as (rule_id, severity, path, message) tuples and exit non-zero
when any finding is produced. Severities mirror standards/FACET_RULEBOOK.md.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Facet base files are core, not facet-owned.
FACET_BASE_FILES = {"src/facets/Facet.sol", "src/facets/IFacet.sol"}

# Reserved storage slots no facet may collide with (ST-2).
RESERVED_SLOTS = {
    # ControllerSharedStorage (src/ControllerSharedStorage.sol)
    "0x77adf60bdbfedf206f8b8310f3d364080b7f61dcc0e46caac13c29bb1eb5cc00":
        "SharedControllerStorage",
    # OZ ReentrancyGuardUpgradeable storage
    "0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00":
        "ReentrancyGuard",
}


class Finding:
    def __init__(self, rule, severity, path, message):
        self.rule = rule
        self.severity = severity
        self.path = str(path)
        self.message = message

    def __str__(self):
        return f"[{self.severity}] {self.rule} {self.path} — {self.message}"


def git(*args, check=True):
    result = subprocess.run(
        ["git", *args], cwd=REPO_ROOT, capture_output=True, text=True
    )
    if check and result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"git {' '.join(args)} failed")
    return result


def changed_files(base):
    """Return {path: {"status": A|M|D|R, "added": int, "deleted": int}} for base...HEAD."""
    out = git("diff", "--numstat", "--diff-filter=ADMR", f"{base}...HEAD").stdout
    status_out = git("diff", "--name-status", f"{base}...HEAD").stdout
    statuses = {}
    for line in status_out.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            # Rename lines are "R<score>\told\tnew" — record the new path.
            statuses[parts[-1]] = parts[0][0]
    files = {}
    for line in out.splitlines():
        added, deleted, path = line.split("\t", 2)
        # Binary files report "-"; treat as changed content.
        files[path] = {
            "status": statuses.get(path, "M"),
            "added": 0 if added == "-" else int(added),
            "deleted": 0 if deleted == "-" else int(deleted),
        }
    return files


def load_manifest(path):
    """Manifest mode: {"files": {path: {status, added, deleted}}, "base_specs": [..],
    "file_root": optional dir containing the file contents to scan}."""
    with open(path) as fh:
        return json.load(fh)


def facet_dirs(files):
    """Facet directories touched by the change set (excluding base files)."""
    dirs = set()
    for path in files:
        if path in FACET_BASE_FILES:
            continue
        m = re.match(r"src/facets/([^/]+)/", path)
        if m:
            dirs.add(m.group(1))
    return sorted(dirs)


def facet_name(dir_name, file_root=REPO_ROOT):
    """Derive the PascalCase facet name from the <Name>Facet.sol file in the dir."""
    d = Path(file_root) / "src" / "facets" / dir_name
    if d.is_dir():
        for f in sorted(d.glob("*Facet.sol")):
            if not f.name.startswith("I"):
                return f.name[: -len("Facet.sol")]
    return None


def read_text(path, file_root=REPO_ROOT):
    p = Path(file_root) / path
    return p.read_text() if p.exists() else None


def exists_at_base(base, path):
    return git("cat-file", "-e", f"{base}:{path}", check=False).returncode == 0


def read_at_base(base, path):
    result = git("show", f"{base}:{path}", check=False)
    return result.stdout if result.returncode == 0 else None


def parse_spec_frontmatter(text):
    """Parse the minimal YAML-ish frontmatter used by specs/ (flat keys, inline lists)."""
    if not text or not text.startswith("---"):
        return {}
    meta = {}
    for line in text.split("---", 2)[1].splitlines():
        m = re.match(r"^(\w[\w-]*):\s*(.*)$", line.strip())
        if not m:
            continue
        key, value = m.group(1), m.group(2).strip()
        if value.startswith("[") and value.endswith("]"):
            items = [v.strip().strip("\"'") for v in value[1:-1].split(",")]
            meta[key] = [v for v in items if v]
        else:
            meta[key] = value.strip("\"'")
    return meta


def strip_comments(source):
    """Remove // and /* */ comments so pattern checks don't fire on prose."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"//[^\n]*", "", source)


def solidity_functions(source):
    """Yield (name, body) for each function in a stripped Solidity source.
    Brace-matching, not a real parser — adequate for the DET rules, and the
    seeded-defect harness pins its behavior."""
    for m in re.finditer(r"\bfunction\s+(\w+)", source):
        i = source.find("{", m.end())
        semi = source.find(";", m.end())
        if i == -1 or (semi != -1 and semi < i):
            continue  # interface/abstract declaration
        depth, j = 1, i + 1
        while j < len(source) and depth:
            if source[j] == "{":
                depth += 1
            elif source[j] == "}":
                depth -= 1
            j += 1
        yield m.group(1), source[i:j]


def report(findings, check_name):
    if findings:
        print(f"\n✗ {check_name}: {len(findings)} finding(s)")
        for f in findings:
            print(f"  {f}")
        return 1
    print(f"✓ {check_name}: clean")
    return 0
