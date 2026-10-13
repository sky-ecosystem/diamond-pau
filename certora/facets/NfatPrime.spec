// NfatPrime.spec
//
// NFATPrimeFacet: the generic facet rules plus rules for each external function. The proxy call is
// summarised: the summary decodes the calldata the facet hands to the proxy, so the rules check its
// target, function and arguments exactly, and lets the call revert or move the proxy's balance of
// the target's gem arbitrarily. That covers every facility and token behaviour, and lets the
// rules check that rate limits are charged with exactly the measured balance change. Approvals made
// through ApproveLib reach the proxy like every other call, with arbitrary token answers, so both of
// its paths (direct, and reset-and-retry) are covered. That the proxy then forwards the calldata
// unchanged is proven by the ALMProxy spec (doCall).

import "FacetBase.spec";

using CallDecoder as decoder;

// --- Methods block ---

methods {
    function getSubscribeRateLimitKey(address, address) external returns (bytes32) envfree;
    function getWithdrawRateLimitKey(address)           external returns (bytes32) envfree;
    function getCollectRateLimitKey(address)            external returns (bytes32) envfree;

    function decoder.decodeCall(bytes)            external returns (uint256, bytes4, uint256, uint256, uint256) envfree;
    function decoder.bytesArgHash(bytes)          external returns (bool, bytes32)                             envfree;
    function decoder.isAcceptedAnswer(bytes)      external returns (bool)                                      envfree;
    function decoder.isInvalidBool(bytes)         external returns (bool)                                      envfree;

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

definition SUBSCRIBE_SELECTOR() returns bytes4 = to_bytes4(0xb2fde4ec);  // subscribe(uint256,bytes)
definition WITHDRAW_SELECTOR()  returns bytes4 = to_bytes4(0x2e1a7d4d);  // withdraw(uint256)
definition COLLECT_SELECTOR()   returns bytes4 = to_bytes4(0xcfa6f827);  // collect(uint256,uint256)
definition APPROVE_SELECTOR()   returns bytes4 = to_bytes4(0x095ea7b3);  // approve(address,uint256)

// --- Summaries ---

persistent ghost gemOf(address) returns address;
persistent ghost mapping(address => mapping(address => uint256)) balanceGhost;

// Every call the facet asks the proxy to make, in order: target, calldata length, selector,
// first two argument words, the forwarded `bytes` argument's
// hash (as in f(uint256, bytes)), the proxy's balance of the target's gem just before the call, whether it
// reverted, and how its answer reads to ApproveLib.
persistent ghost mathint doCalls;
persistent ghost mapping(mathint => address) callTarget;
persistent ghost mapping(mathint => uint256) callLength;
persistent ghost mapping(mathint => bytes4)  callSelector;
persistent ghost mapping(mathint => uint256) callWord0;
persistent ghost mapping(mathint => uint256) callWord1;
persistent ghost mapping(mathint => bool)    callBytesArgWellFormed;
persistent ghost mapping(mathint => bytes32) callBytesArgHash;
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

    bool    argWellFormed;
    bytes32 argHash;
    argWellFormed, argHash = decoder.bytesArgHash(data);

    callBytesArgWellFormed[i] = argWellFormed;
    callBytesArgHash[i]       = argHash;

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

// --- External Calls Affected Rule ---

// Only the three allocator actions reach outside the facet. A function added later that calls out
// fails this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 =>
        f.selector == sig:subscribe(address, uint256, bytes).selector ||
        f.selector == sig:withdraw(address, uint256).selector ||
        f.selector == sig:collect(address, uint256, uint256).selector;
}

// --- View function correctness ---

// Each action and each facility (and gem, for subscriptions) has its own limit
rule rateLimitKeys_distinct(address facility1, address gem1, address facility2, address gem2) {
    assert facility1 != facility2 || gem1 != gem2 =>
        getSubscribeRateLimitKey(facility1, gem1) != getSubscribeRateLimitKey(facility2, gem2);
    assert facility1 != facility2 => getWithdrawRateLimitKey(facility1) != getWithdrawRateLimitKey(facility2);
    assert facility1 != facility2 => getCollectRateLimitKey(facility1)  != getCollectRateLimitKey(facility2);
    assert getWithdrawRateLimitKey(facility1) != getCollectRateLimitKey(facility2);
    assert getSubscribeRateLimitKey(facility1, gem1) != getWithdrawRateLimitKey(facility2);
    assert getSubscribeRateLimitKey(facility1, gem1) != getCollectRateLimitKey(facility2);
}

// --- Allocator functions: subscribe ---

// Approves the facility for `amount`, subscribes with `amount` and `data`, resets the approval, and
// charges the subscribe limit with what the proxy spent from the facility call on. There is no
// zero-amount check, unlike withdraw and collect.
//
// Each approval is one call, or three when the token's first answer is rejected, so the facility
// call is call 1 or 3 and the run makes 3, 5 or 7 calls. Every one is checked at its index.
rule subscribe(address facility, uint256 amount, bytes data) {
    env e;

    setupRecorders();

    address proxy = proxySlot();
    address gem   = gemOf(facility);

    subscribe(e, facility, amount, data);

    uint256 balanceAfter  = balanceGhost[gem][proxy];
    mathint facilityIndex = accepted(0) ? 1 : 3;
    mathint resetIndex    = facilityIndex + 1;

    // Approval of the gem to the facility for `amount`: call 0, followed by approve(0) and the
    // approve again when its answer is rejected
    assert isApproveCall(0, gem, facility, amount);
    assert !accepted(0) => isApproveCall(1, gem, facility, 0) && isApproveCall(2, gem, facility, amount);

    // Then the facility call: facility.subscribe(amount, data), with `data` forwarded unchanged
    assert callTarget[facilityIndex]   == facility;
    assert callSelector[facilityIndex] == SUBSCRIBE_SELECTOR();
    assert callWord0[facilityIndex]    == amount;
    assert callBytesArgWellFormed[facilityIndex];
    assert callBytesArgHash[facilityIndex] == keccak256(data);

    // Then the approval reset to zero: call `resetIndex`, followed by two more approve(0) when its
    // answer is rejected, and nothing else
    assert isApproveCall(resetIndex, gem, facility, 0);
    assert !accepted(resetIndex) =>
        isApproveCall(resetIndex + 1, gem, facility, 0) && isApproveCall(resetIndex + 2, gem, facility, 0);
    assert doCalls == (accepted(resetIndex) ? resetIndex + 1 : resetIndex + 3);

    // Rate limit: charged once, after the calls, with the spend measured from the facility call on
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getSubscribeRateLimitKey(facility, gem);
    assert lastDecreasedAmount == callBalanceBefore[facilityIndex] - balanceAfter;
}

// The two directions are stated separately. The first call of each approval is a low-level call,
// and when it reverts, ApproveLib copies the revert data into memory. The prover does not bound
// that data's size, so it can leave the free-memory pointer next to the 2^64 limit, and the next
// allocation then reverts. On chain, that much memory runs out of gas first. Reverts after such a
// caught failure are therefore allowed in the second direction.
rule subscribe_revert(address facility, uint256 amount, bytes data) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    subscribe@withrevert(e, facility, amount, data);

    bool reverted = lastReverted;

    mathint facilityIndex = accepted(0) ? 1 : 3;
    bool    called        = made(facilityIndex) && !callReverted[facilityIndex];

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = approvalReverts(0);
    bool revert5 = failed(facilityIndex);
    bool revert6 = called && approvalReverts(facilityIndex + 1);
    bool revert7 = called && balanceGhost[gem][proxy] > callBalanceBefore[facilityIndex];

    bool caughtFailure = failed(0) || (called && failed(facilityIndex + 1));

    // Each of these makes the call revert
    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 => reverted;
    // And nothing else does, except running out of memory after a caught failure
    assert reverted => revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 ||
                       caughtFailure;
}

// --- Allocator functions: withdraw ---

// Withdraws `amount` from the facility and charges the withdraw limit with what the proxy actually
// received
rule withdraw(address facility, uint256 amount) {
    env e;

    setupRecorders();

    address proxy         = proxySlot();
    address gem           = gemOf(facility);
    uint256 balanceBefore = balanceGhost[gem][proxy];

    withdraw(e, facility, amount);

    uint256 balanceAfter = balanceGhost[gem][proxy];

    // Exactly one proxy call, and no approvals: facility.withdraw(amount)
    assert doCalls == 1;
    assert callTarget[0]   == facility;
    assert callLength[0]   == 36;
    assert callSelector[0] == WITHDRAW_SELECTOR();
    assert callWord0[0]    == amount;

    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getWithdrawRateLimitKey(facility);
    assert lastDecreasedAmount == balanceAfter - balanceBefore;
}

rule withdraw_revert(address facility, uint256 amount) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 balanceBefore     = balanceGhost[gem][proxy];
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    withdraw@withrevert(e, facility, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = amount == 0;
    bool revert5 = failed(0);
    bool revert6 = made(0) && !callReverted[0] && balanceGhost[gem][proxy] < balanceBefore;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6;
}

// --- Allocator functions: collect ---

// Collects `amount` for `tokenId` from the facility and charges the collect limit with what the
// proxy actually received
rule collect(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy         = proxySlot();
    address gem           = gemOf(facility);
    uint256 balanceBefore = balanceGhost[gem][proxy];

    collect(e, facility, tokenId, amount);

    uint256 balanceAfter = balanceGhost[gem][proxy];

    // Exactly one proxy call, and no approvals: facility.collect(tokenId, amount)
    assert doCalls == 1;
    assert callTarget[0]   == facility;
    assert callLength[0]   == 68;
    assert callSelector[0] == COLLECT_SELECTOR();
    assert callWord0[0]    == tokenId;
    assert callWord1[0]    == amount;

    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getCollectRateLimitKey(facility);
    assert lastDecreasedAmount == balanceAfter - balanceBefore;
}

rule collect_revert(address facility, uint256 tokenId, uint256 amount) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address gem               = gemOf(facility);
    uint256 balanceBefore     = balanceGhost[gem][proxy];
    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    collect@withrevert(e, facility, tokenId, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = amount == 0;
    bool revert5 = failed(0);
    bool revert6 = made(0) && !callReverted[0] && balanceGhost[gem][proxy] < balanceBefore;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6;
}
