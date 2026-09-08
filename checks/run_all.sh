#!/usr/bin/env bash
# Deterministic facet-gate entrypoint. Mirrors the CI `Facet Gate / Deterministic
# checks` job exactly — a clean local run means a clean CI run.
#
# Usage:
#   ./checks/run_all.sh [--base <ref>] [--skip-coverage]
#
# --base defaults to the merge-base with origin/dev.
# --skip-coverage skips the (slow) forge-coverage check for quick iteration; the
#   full gate in CI always runs it.

set -uo pipefail
cd "$(dirname "$0")/.."

BASE=""
SKIP_COVERAGE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base) BASE="$2"; shift 2 ;;
        --skip-coverage) SKIP_COVERAGE=1; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$BASE" ]]; then
    git fetch origin dev --quiet 2>/dev/null || true
    BASE="$(git merge-base HEAD origin/dev)"
fi
echo "Facet gate — deterministic checks (base: $BASE)"

FAILED=0
run() {
    python3 "$@" || FAILED=1
}

run checks/check_diff_scope.py --base "$BASE"
run checks/check_structure.py  --base "$BASE"
run checks/check_forbidden.py  --base "$BASE"
run checks/check_storage.py    --base "$BASE"

if [[ "$SKIP_COVERAGE" -eq 0 ]]; then
    run checks/check_coverage.py --base "$BASE"
else
    echo "⚠ check_coverage: skipped (--skip-coverage) — CI will run it"
fi

echo
if [[ "$FAILED" -ne 0 ]]; then
    echo "✗ Facet gate: FAILED — fix the findings above; rule IDs are defined in standards/FACET_RULEBOOK.md"
    exit 1
fi
echo "✓ Facet gate: all deterministic checks passed"
