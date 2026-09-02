#!/usr/bin/env bash
# Gate self-test: every seeded defect must be caught with its expected rule ID, and the
# clean baseline must pass every check. Runs in CI (Facet Gate / Gate self-test) and
# must stay green — which forces the rulebook, the checks, and these fixtures to evolve
# together. Requires python3 + foundry's `cast` on PATH.

set -uo pipefail
cd "$(dirname "$0")/../.."

CHECKS=checks
FX=checks/fixtures
PASS=0
FAIL=0

expect_fail() {
    local label="$1" rule="$2"; shift 2
    local out rc
    out=$("$@" 2>&1); rc=$?
    if [[ $rc -eq 0 ]]; then
        echo "✗ $label — expected failure, check passed (seed not caught!)"
        FAIL=$((FAIL + 1))
    elif ! grep -q "$rule" <<<"$out"; then
        echo "✗ $label — failed, but without expected rule $rule:"
        sed 's/^/    /' <<<"$out"
        FAIL=$((FAIL + 1))
    else
        echo "✓ $label ($rule caught)"
        PASS=$((PASS + 1))
    fi
}

expect_pass() {
    local label="$1"; shift
    local out rc
    out=$("$@" 2>&1); rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "✗ $label — clean fixture flagged (false positive!):"
        sed 's/^/    /' <<<"$out"
        FAIL=$((FAIL + 1))
    else
        echo "✓ $label"
        PASS=$((PASS + 1))
    fi
}

echo "── clean baseline (false-positive pinning) ──"
expect_pass "clean: structure"  python3 $CHECKS/check_structure.py --facet-file $FX/clean/CleanFacet.sol $FX/clean/ICleanFacet.sol
expect_pass "clean: forbidden"  python3 $CHECKS/check_forbidden.py --source $FX/clean/CleanFacet.sol --test $FX/clean/Clean.t.sol
expect_pass "clean: storage"    python3 $CHECKS/check_storage.py   --source $FX/clean/CleanFacet.sol
expect_pass "clean: diff scope" python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M06_clean.json

echo "── seeded defects (must all be caught) ──"
expect_fail "S01 doDelegateCall"      "V-1"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S01_delegatecall/CleanFacet.sol
expect_fail "S02 ACL grantRole"       "A-3"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S02_acl/CleanFacet.sol
expect_fail "S03 storage alias"       "ST-2" python3 $CHECKS/check_storage.py   --source $FX/seeded/S03_storage_alias/CleanFacet.sol
expect_fail "S04 storage mismatch"    "ST-1" python3 $CHECKS/check_storage.py   --source $FX/seeded/S04_storage_mismatch/CleanFacet.sol
expect_fail "S05 rogue state var"     "ST-1" python3 $CHECKS/check_storage.py   --source $FX/seeded/S05_rogue_statevar/CleanFacet.sol
expect_fail "S06 custom error"        "E-3"  python3 $CHECKS/check_structure.py --facet-file $FX/seeded/S06_custom_error/CleanFacet.sol
expect_fail "S07 dangling approval"   "V-4"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S07_dangling_approval/CleanFacet.sol
expect_fail "S08 new role"            "A-1"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S08_new_role/CleanFacet.sol
expect_fail "S09 receive()"           "V-7"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S09_receive/CleanFacet.sol
expect_fail "S10 TODO marker"         "G-5"  python3 $CHECKS/check_structure.py --facet-file $FX/seeded/S10_todo/CleanFacet.sol
expect_fail "S11 prank(controller)"   "T-5"  python3 $CHECKS/check_forbidden.py --test $FX/seeded/S11_prank_controller/Clean.t.sol
expect_fail "S12 event in impl"       "E-1"  python3 $CHECKS/check_structure.py --facet-file $FX/seeded/S12_event_in_impl/CleanFacet.sol
expect_fail "S13 arbitrary assembly"  "V-8"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S13_assembly/CleanFacet.sol
expect_fail "S14 lib import"          "S-6"  python3 $CHECKS/check_forbidden.py --source $FX/seeded/S14_lib_import/CleanFacet.sol

echo "── diff-scope manifests ──"
expect_fail "M01 core contract touch" "G-2"  python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M01_core_touch.json
expect_fail "M02 missing spec"        "G-1"  python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M02_no_spec.json
expect_fail "M03 additive violation"  "G-2"  python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M03_additive_violation.json
expect_fail "M04 undeclared dep"      "G-3"  python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M04_undeclared_dep.json
expect_fail "M05 spec touched"        "G-1"  python3 $CHECKS/check_diff_scope.py --manifest $FX/manifests/M05_spec_touch.json

echo
echo "gate self-test: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
echo "Note: judgment seeds in checks/fixtures/judgment/ are invisible to these scripts"
echo "by design — they validate the adversarial reviewer (see fixtures README)."
