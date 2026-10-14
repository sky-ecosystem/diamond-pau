// NfatHalo.spec
//
// NFATHaloFacet: the generic facet rules plus rules for each external function. As in NfatPrime,
// the proxy call is summarised: the summary decodes the calldata the facet hands to the proxy, so
// the rules check its target, function and arguments exactly, and lets the call revert or move the
// proxy's balance of the target's gem arbitrarily. Approvals made through ApproveLib reach the
// proxy like every other call, with arbitrary token answers, so both of its paths (direct, and
// reset-and-retry) are covered.
//

import "FacetBase.spec";

using CallDecoder as decoder;

// --- Methods block ---

methods {
    function getIssueRateLimitKey(address, address)          external returns (bytes32) envfree;
    function getRepayPrincipalRateLimitKey(address, address) external returns (bytes32) envfree;
    function getRepayInterestRateLimitKey(address, address)  external returns (bytes32) envfree;
    function getMaxAnnualGrowthRate(address)                 external returns (uint256) envfree;
    function getFacilityState(address)                       external returns (uint256, uint256) envfree;
    function getPosition(address, uint256)                   external returns (bool, uint256, uint256, uint256) envfree;

    function decoder.decodeCall(bytes)       external returns (uint256, bytes4, uint256, uint256, uint256) envfree;
    function decoder.isAcceptedAnswer(bytes) external returns (bool)                                      envfree;
    function decoder.isInvalidBool(bytes)    external returns (bool)                                      envfree;

    function _.doCall(address target, bytes data) external => cvlDoCall(calledContract, target, data) expect bytes;

    // Facility and token reads (static calls)
    function _.gem()                      external => gemOf(calledContract)                 expect address;
    function _.balanceOf(address account) external => balanceGhost[calledContract][account] expect uint256;
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule rateLimitCallsAreFacetCalls;
use rule allocatorRequiresRateLimit;
use rule noForbiddenCalls;
use rule noProxyDelegateCalls;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// --- Definitions ---

override definition OWN_NAMESPACE() returns uint8 = NAMESPACE_NFATHaloFacet_v1();

definition ISSUE_SELECTOR()   returns bytes4 = to_bytes4(0xdfe5ef48);  // issue(address,uint256,uint256)
definition REPAY_SELECTOR()   returns bytes4 = to_bytes4(0xd8aed145);  // repay(uint256,uint256)
definition APPROVE_SELECTOR() returns bytes4 = to_bytes4(0x095ea7b3);  // approve(address,uint256)

definition INTEREST_RATE_PRECISION() returns mathint = 10^18;

// sky.pau.storage.NFATHaloFacet.v1
definition growthRateOf(address f)                returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.parameters[f].maxAnnualGrowthRate;
definition stateIndexOf(address f)                returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.states[f].interestIndex;
definition stateUpdatedOf(address f)              returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.states[f].lastUpdated;
definition issuedOf(address f, uint256 id)        returns bool    = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.positions[f][id].issued;
definition principalOf(address f, uint256 id)     returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.positions[f][id].outstandingPrincipal;
definition maxInterestOf(address f, uint256 id)   returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.positions[f][id].maxOutstandingInterest;
definition positionIndexOf(address f, uint256 id) returns uint256 = currentContract.ext_sky_pau_storage_NFATHaloFacet_v1.positions[f][id].interestIndex;

// The facility index after _checkpointFacility at `timestamp`
definition YEAR() returns mathint = 365 * 24 * 60 * 60;

// The facility's current interest index, as _getCurrentInterestIndex computes it
definition currentIndex(address f, uint256 timestamp) returns mathint =
    stateUpdatedOf(f) == 0
        ? stateIndexOf(f)
        : stateIndexOf(f) + growthRateOf(f) * (timestamp - stateUpdatedOf(f)) / YEAR();

definition checkpointedIndex(address f, uint256 timestamp) returns mathint =
    stateUpdatedOf(f) == timestamp ? stateIndexOf(f) : currentIndex(f, timestamp);

// _checkpointFacility reverts: it computes the index (not updated in this block, and updated
// before), and the last update is in the future, or the multiplication or the addition overflows
definition checkpointFacilityReverts(address f, uint256 timestamp) returns bool =
    stateUpdatedOf(f) != timestamp && stateUpdatedOf(f) != 0 && (
        stateUpdatedOf(f) > timestamp ||
        growthRateOf(f) * (timestamp - stateUpdatedOf(f)) > max_uint256 ||
        stateIndexOf(f) + growthRateOf(f) * (timestamp - stateUpdatedOf(f)) / YEAR() > max_uint256
    );

// Interest accrued by a position up to index `index`, as _checkpointPosition computes it
definition accrued(address f, uint256 id, mathint index) returns mathint =
    principalOf(f, id) * (index - positionIndexOf(f, id)) / INTEREST_RATE_PRECISION();

// _checkpointPosition reverts: the position is not issued, the index went backwards, or the
// multiplication or the addition overflows
definition checkpointPositionReverts(address f, uint256 id, mathint index) returns bool =
    !issuedOf(f, id) ||
    index < positionIndexOf(f, id) ||
    principalOf(f, id) * (index - positionIndexOf(f, id)) > max_uint256 ||
    maxInterestOf(f, id) + accrued(f, id, index) > max_uint256;

// --- Summaries ---

persistent ghost gemOf(address) returns address;
persistent ghost mapping(address => mapping(address => uint256)) balanceGhost;

// Every call the facet asks the proxy to make, in order: target, calldata length, selector,
// first three argument words, the proxy's balance of the target's gem just before the call, whether it
// reverted, and how its answer reads to ApproveLib.
persistent ghost mathint doCalls;
persistent ghost mapping(mathint => address) callTarget;
persistent ghost mapping(mathint => uint256) callLength;
persistent ghost mapping(mathint => bytes4)  callSelector;
persistent ghost mapping(mathint => uint256) callWord0;
persistent ghost mapping(mathint => uint256) callWord1;
persistent ghost mapping(mathint => uint256) callWord2;
persistent ghost mapping(mathint => uint256) callBalanceBefore;
persistent ghost mapping(mathint => bool)    callReverted;
persistent ghost mapping(mathint => bool)    callAnswerAccepted;
persistent ghost mapping(mathint => bool)    callAnswerInvalid;

// Any proxy call either reverts, or moves the proxy's balance of the target's gem to an arbitrary
// value and returns an arbitrary answer
function cvlDoCall(address proxy, address target, bytes data) returns bytes {
    mathint i = doCalls;
    doCalls = doCalls + 1;

    uint256 length;
    bytes4  selector;
    uint256 word0;
    uint256 word1;
    uint256 word2;
    length, selector, word0, word1, word2 = decoder.decodeCall(data);

    callTarget[i]   = target;
    callLength[i]   = length;
    callSelector[i] = selector;
    callWord0[i]    = word0;
    callWord1[i]    = word1;
    callWord2[i]    = word2;

    callBalanceBefore[i] = balanceGhost[gemOf(target)][proxy];

    bool reverts;
    callReverted[i] = reverts;
    if (reverts) {
        revert("proxy call failed");
    }

    uint256 newBalance;
    balanceGhost[gemOf(target)][proxy] = newBalance;

    bytes answer;
    callAnswerAccepted[i] = decoder.isAcceptedAnswer(answer);
    callAnswerInvalid[i]  = decoder.isInvalidBool(answer);

    return answer;
}

// Call i was made; it reverted; it returned an answer ApproveLib accepts; it returned a word that
// does not decode as a bool
definition made(mathint i)          returns bool = doCalls > i;
definition failed(mathint i)        returns bool = made(i) && callReverted[i];
definition accepted(mathint i)      returns bool = made(i) && !callReverted[i] && callAnswerAccepted[i];
definition invalidAnswer(mathint i) returns bool = made(i) && !callReverted[i] && callAnswerInvalid[i];

// A proxy call is `token.approve(spender, amount)`
definition isApproveCall(mathint i, address token, address spender, uint256 amount) returns bool =
    callTarget[i]   == token &&
    callLength[i]   == 68 &&
    callSelector[i] == APPROVE_SELECTOR() &&
    callWord0[i]    == to_mathint(spender) &&
    callWord1[i]    == amount;

// ApproveLib.approve whose first call is call k reverts. That call goes through a low-level call,
// so its revert is caught. If its answer is accepted, the approval is that one call; otherwise
// approve(0) and the approve again follow, and the last answer must be accepted. An answer that
// does not decode as a bool reverts at once.
definition approvalReverts(mathint k) returns bool =
    invalidAnswer(k) ||
    (made(k) && !accepted(k) && !invalidAnswer(k) &&
        (failed(k + 1) || failed(k + 2) || (made(k + 2) && !accepted(k + 2))));

function setupRecorders() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require doCalls == 0;
}

// --- Storage Affected Rule ---

rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    address anyFacility;
    uint256 anyTokenId;

    uint256 growthRateBefore    = growthRateOf(anyFacility);
    uint256 stateIndexBefore    = stateIndexOf(anyFacility);
    uint256 stateUpdatedBefore  = stateUpdatedOf(anyFacility);
    bool    issuedBefore        = issuedOf(anyFacility, anyTokenId);
    uint256 principalBefore     = principalOf(anyFacility, anyTokenId);
    uint256 maxInterestBefore   = maxInterestOf(anyFacility, anyTokenId);
    uint256 positionIndexBefore = positionIndexOf(anyFacility, anyTokenId);

    f(e, args);

    // The growth rate is configuration
    assert growthRateOf(anyFacility) != growthRateBefore =>
        f.selector == sig:setMaxAnnualGrowthRate(address, uint256).selector;

    // Every function that touches a facility checkpoints it
    assert stateIndexOf(anyFacility) != stateIndexBefore || stateUpdatedOf(anyFacility) != stateUpdatedBefore =>
        f.selector == sig:setMaxAnnualGrowthRate(address, uint256).selector ||
        f.selector == sig:issue(address, address, uint256, uint256).selector ||
        f.selector == sig:repayPrincipal(address, uint256, uint256).selector ||
        f.selector == sig:repayInterest(address, uint256, uint256).selector;

    // Positions are only created by issue
    assert issuedOf(anyFacility, anyTokenId) != issuedBefore =>
        f.selector == sig:issue(address, address, uint256, uint256).selector;

    // Positions are only changed by issue and the repayments
    assert principalOf(anyFacility, anyTokenId) != principalBefore ||
           maxInterestOf(anyFacility, anyTokenId) != maxInterestBefore ||
           positionIndexOf(anyFacility, anyTokenId) != positionIndexBefore =>
        f.selector == sig:issue(address, address, uint256, uint256).selector ||
        f.selector == sig:repayPrincipal(address, uint256, uint256).selector ||
        f.selector == sig:repayInterest(address, uint256, uint256).selector;
}

// --- External Calls Affected Rule ---

// Only the three allocator actions reach outside the facet. A function added later that calls out
// fails this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 =>
        f.selector == sig:issue(address, address, uint256, uint256).selector ||
        f.selector == sig:repayPrincipal(address, uint256, uint256).selector ||
        f.selector == sig:repayInterest(address, uint256, uint256).selector;
}

// --- View function correctness ---

rule getters_correctness(address facility, uint256 tokenId) {
    assert getMaxAnnualGrowthRate(facility) == growthRateOf(facility);

    uint256 index;
    uint256 updated;
    index, updated = getFacilityState(facility);
    assert index == stateIndexOf(facility);
    assert updated == stateUpdatedOf(facility);

    bool    issued;
    uint256 principal;
    uint256 maxInterest;
    uint256 positionIndex;
    issued, principal, maxInterest, positionIndex = getPosition(facility, tokenId);
    assert issued        == issuedOf(facility, tokenId);
    assert principal     == principalOf(facility, tokenId);
    assert maxInterest   == maxInterestOf(facility, tokenId);
    assert positionIndex == positionIndexOf(facility, tokenId);
}

// Each action has its own limit, per facility and recipient (issue) or facility and gem (repay)
rule rateLimitKeys_distinct(address facility1, address account1, address facility2, address account2) {
    assert facility1 != facility2 || account1 != account2 =>
        getIssueRateLimitKey(facility1, account1) != getIssueRateLimitKey(facility2, account2);
    assert facility1 != facility2 || account1 != account2 =>
        getRepayPrincipalRateLimitKey(facility1, account1) != getRepayPrincipalRateLimitKey(facility2, account2);
    assert facility1 != facility2 || account1 != account2 =>
        getRepayInterestRateLimitKey(facility1, account1) != getRepayInterestRateLimitKey(facility2, account2);
    assert getRepayPrincipalRateLimitKey(facility1, account1) != getRepayInterestRateLimitKey(facility2, account2);
    assert getIssueRateLimitKey(facility1, account1) != getRepayPrincipalRateLimitKey(facility2, account2);
    assert getIssueRateLimitKey(facility1, account1) != getRepayInterestRateLimitKey(facility2, account2);
}

// --- Admin functions: setMaxAnnualGrowthRate ---

// Checkpoints the facility at the old rate, then sets the new rate for that facility only
rule setMaxAnnualGrowthRate(address facility, uint256 rate) {
    env e;

    address otherFacility;
    require otherFacility != facility;

    mathint index                 = checkpointedIndex(facility, e.block.timestamp);
    uint256 otherRateBefore       = growthRateOf(otherFacility);
    uint256 otherStateIndexBefore = stateIndexOf(otherFacility);

    setMaxAnnualGrowthRate(e, facility, rate);

    assert growthRateOf(facility)   == rate;
    assert stateIndexOf(facility)   == index;
    assert stateUpdatedOf(facility) == e.block.timestamp;

    assert growthRateOf(otherFacility) == otherRateBefore;
    assert stateIndexOf(otherFacility) == otherStateIndexBefore;
}

rule setMaxAnnualGrowthRate_revert(address facility, uint256 rate) {
    env e;

    uint256 statusBefore      = status();
    bool    senderIsAdmin     = isAdmin(e.msg.sender);
    bool    checkpointReverts = checkpointFacilityReverts(facility, e.block.timestamp);

    setMaxAnnualGrowthRate@withrevert(e, facility, rate);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = facility == 0;
    bool revert5 = checkpointReverts;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}

// --- Allocator functions: issue ---

// Issues the NFAT, opens the position with the principal actually received at the facility's
// checkpointed index, and charges the issue limit of (facility, to) with that received amount
rule issue(address facility, address to, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy         = proxySlot();
    address gem           = gemOf(facility);
    uint256 balanceBefore = balanceGhost[gem][proxy];
    mathint index         = checkpointedIndex(facility, e.block.timestamp);

    issue(e, facility, to, tokenId, amount);

    mathint received = balanceGhost[gem][proxy] - balanceBefore;

    // Exactly one proxy call, and no approvals: facility.issue(to, tokenId, amount)
    assert doCalls == 1;
    assert callTarget[0]   == facility;
    assert callLength[0]   == 100;
    assert callSelector[0] == ISSUE_SELECTOR();
    assert callWord0[0]    == to_mathint(to);
    assert callWord1[0]    == tokenId;
    assert callWord2[0]    == amount;

    // Position: opened with the received principal at the checkpointed index
    assert issuedOf(facility, tokenId);
    assert principalOf(facility, tokenId)     == received;
    assert positionIndexOf(facility, tokenId) == index;
    assert stateIndexOf(facility)             == index;
    assert stateUpdatedOf(facility)           == e.block.timestamp;

    // Rate limit: charged once, after the call, with the received amount
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getIssueRateLimitKey(facility, to);
    assert lastDecreasedAmount == received;
}

rule issue_revert(address facility, address to, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 balanceBefore     = balanceGhost[gem][proxy];
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);
    bool    alreadyIssued     = issuedOf(facility, tokenId);
    bool    checkpointReverts = checkpointFacilityReverts(facility, e.block.timestamp);

    issue@withrevert(e, facility, to, tokenId, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = amount == 0;
    bool revert5 = alreadyIssued;
    bool revert6 = failed(0);
    bool revert7 = made(0) && !callReverted[0] && balanceGhost[gem][proxy] < balanceBefore;
    bool revert8 = checkpointReverts;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6 ||
                            revert7 || revert8;
}

// --- Allocator functions: repayPrincipal ---

// Accrues interest on the position, repays at most the outstanding principal through the facility,
// reduces the principal by what was actually spent, and charges the principal limit with it
rule repayPrincipal(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy       = proxySlot();
    address gem         = gemOf(facility);
    mathint index       = checkpointedIndex(facility, e.block.timestamp);
    mathint principal   = principalOf(facility, tokenId);
    mathint maxInterest = maxInterestOf(facility, tokenId) + accrued(facility, tokenId, index);

    repayPrincipal(e, facility, tokenId, amount);

    mathint facilityIndex = accepted(0) ? 1 : 3;
    mathint resetIndex    = facilityIndex + 1;
    mathint spent         = callBalanceBefore[facilityIndex] - balanceGhost[gem][proxy];

    // Approval of the gem to the facility for `amount`: call 0, followed by approve(0) and the
    // approve again when its answer is rejected
    assert isApproveCall(0, gem, facility, amount);
    assert !accepted(0) => isApproveCall(1, gem, facility, 0) && isApproveCall(2, gem, facility, amount);

    // Then the facility call: facility.repay(tokenId, amount)
    assert callTarget[facilityIndex]   == facility;
    assert callLength[facilityIndex]   == 68;
    assert callSelector[facilityIndex] == REPAY_SELECTOR();
    assert callWord0[facilityIndex]    == tokenId;
    assert callWord1[facilityIndex]    == amount;

    // Then the approval reset to zero: call `resetIndex`, followed by two more approve(0) when its
    // answer is rejected, and nothing else
    assert isApproveCall(resetIndex, gem, facility, 0);
    assert !accepted(resetIndex) =>
        isApproveCall(resetIndex + 1, gem, facility, 0) && isApproveCall(resetIndex + 2, gem, facility, 0);
    assert doCalls == (accepted(resetIndex) ? resetIndex + 1 : resetIndex + 3);

    // Position: interest accrued to the checkpointed index, principal reduced by the spend
    assert principalOf(facility, tokenId)     == principal - spent;
    assert maxInterestOf(facility, tokenId)   == maxInterest;
    assert positionIndexOf(facility, tokenId) == index;

    // Rate limit: charged once, after the calls, with the spend measured from the facility call on
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getRepayPrincipalRateLimitKey(facility, gem);
    assert lastDecreasedAmount == spent;
}

// The two directions are stated separately. The first call of each approval is a low-level call,
// and when it reverts, ApproveLib copies the revert data into memory. The prover does not bound
// that data's size, so it can leave the free-memory pointer next to the 2^64 limit, and the next
// allocation then reverts. On chain, that much memory runs out of gas first. Reverts after such a
// caught failure are therefore allowed in the second direction.
rule repayPrincipal_revert(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);
    mathint index             = checkpointedIndex(facility, e.block.timestamp);
    bool    checkpointReverts = checkpointPositionReverts(facility, tokenId, index);
    bool    facilityReverts   = checkpointFacilityReverts(facility, e.block.timestamp);
    mathint principal         = principalOf(facility, tokenId);

    repayPrincipal@withrevert(e, facility, tokenId, amount);

    bool reverted = lastReverted;

    mathint facilityIndex = accepted(0) ? 1 : 3;
    bool    called        = made(facilityIndex) && !callReverted[facilityIndex];
    mathint spent         = callBalanceBefore[facilityIndex] - balanceGhost[gem][proxy];

    bool revert1  = e.msg.value > 0;
    bool revert2  = statusBefore == ENTERED();
    bool revert3  = !senderIsAllocator;
    bool revert4  = amount == 0;
    bool revert5  = checkpointReverts;
    bool revert6  = amount > principal;
    bool revert7  = approvalReverts(0);
    bool revert8  = failed(facilityIndex);
    bool revert9  = called && approvalReverts(facilityIndex + 1);
    bool revert10 = called && (spent < 0 || spent > principal);
    bool revert11 = facilityReverts;

    bool caughtFailure = failed(0) || (called && failed(facilityIndex + 1));

    // Each of these makes the call revert
    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 ||
           revert9 || revert10 || revert11 => reverted;
    // And nothing else does, except running out of memory after a caught failure
    assert reverted => revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 ||
                       revert8 || revert9 || revert10 || revert11 || caughtFailure;
}

// --- Allocator functions: repayInterest ---

// Accrues interest on the position, repays at most the maximum outstanding interest through the
// facility, reduces it by what was actually spent, and charges the interest limit with it
rule repayInterest(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy       = proxySlot();
    address gem         = gemOf(facility);
    mathint index       = checkpointedIndex(facility, e.block.timestamp);
    mathint principal   = principalOf(facility, tokenId);
    mathint maxInterest = maxInterestOf(facility, tokenId) + accrued(facility, tokenId, index);

    repayInterest(e, facility, tokenId, amount);

    mathint facilityIndex = accepted(0) ? 1 : 3;
    mathint resetIndex    = facilityIndex + 1;
    mathint spent         = callBalanceBefore[facilityIndex] - balanceGhost[gem][proxy];

    // Approval of the gem to the facility for `amount`: call 0, followed by approve(0) and the
    // approve again when its answer is rejected
    assert isApproveCall(0, gem, facility, amount);
    assert !accepted(0) => isApproveCall(1, gem, facility, 0) && isApproveCall(2, gem, facility, amount);

    // Then the facility call: facility.repay(tokenId, amount)
    assert callTarget[facilityIndex]   == facility;
    assert callLength[facilityIndex]   == 68;
    assert callSelector[facilityIndex] == REPAY_SELECTOR();
    assert callWord0[facilityIndex]    == tokenId;
    assert callWord1[facilityIndex]    == amount;

    // Then the approval reset to zero: call `resetIndex`, followed by two more approve(0) when its
    // answer is rejected, and nothing else
    assert isApproveCall(resetIndex, gem, facility, 0);
    assert !accepted(resetIndex) =>
        isApproveCall(resetIndex + 1, gem, facility, 0) && isApproveCall(resetIndex + 2, gem, facility, 0);
    assert doCalls == (accepted(resetIndex) ? resetIndex + 1 : resetIndex + 3);

    // Position: interest accrued to the checkpointed index, then reduced by the spend
    assert principalOf(facility, tokenId)     == principal;
    assert maxInterestOf(facility, tokenId)   == maxInterest - spent;
    assert positionIndexOf(facility, tokenId) == index;

    // Rate limit: charged once, after the calls, with the spend measured from the facility call on
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getRepayInterestRateLimitKey(facility, gem);
    assert lastDecreasedAmount == spent;
}

// The two directions are stated separately. The first call of each approval is a low-level call,
// and when it reverts, ApproveLib copies the revert data into memory. The prover does not bound
// that data's size, so it can leave the free-memory pointer next to the 2^64 limit, and the next
// allocation then reverts. On chain, that much memory runs out of gas first. Reverts after such a
// caught failure are therefore allowed in the second direction.
rule repayInterest_revert(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);
    mathint index             = checkpointedIndex(facility, e.block.timestamp);
    bool    checkpointReverts = checkpointPositionReverts(facility, tokenId, index);
    bool    facilityReverts   = checkpointFacilityReverts(facility, e.block.timestamp);
    mathint maxInterest       = maxInterestOf(facility, tokenId) + accrued(facility, tokenId, index);

    repayInterest@withrevert(e, facility, tokenId, amount);

    bool reverted = lastReverted;

    mathint facilityIndex = accepted(0) ? 1 : 3;
    bool    called        = made(facilityIndex) && !callReverted[facilityIndex];
    mathint spent         = callBalanceBefore[facilityIndex] - balanceGhost[gem][proxy];

    bool revert1  = e.msg.value > 0;
    bool revert2  = statusBefore == ENTERED();
    bool revert3  = !senderIsAllocator;
    bool revert4  = amount == 0;
    bool revert5  = checkpointReverts;
    bool revert6  = amount > maxInterest;
    bool revert7  = approvalReverts(0);
    bool revert8  = failed(facilityIndex);
    bool revert9  = called && approvalReverts(facilityIndex + 1);
    bool revert10 = called && (spent < 0 || spent > maxInterest);
    bool revert11 = facilityReverts;

    bool caughtFailure = failed(0) || (called && failed(facilityIndex + 1));

    // Each of these makes the call revert
    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 ||
           revert9 || revert10 || revert11 => reverted;
    // And nothing else does, except running out of memory after a caught failure
    assert reverted => revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 ||
                       revert8 || revert9 || revert10 || revert11 || caughtFailure;
}
