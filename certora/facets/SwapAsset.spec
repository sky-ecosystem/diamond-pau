// SwapAsset.spec
//
// SwapAssetFacet: the generic facet rules plus rules for each external function. The proxy call is
// summarised: the summary decodes the calldata the facet hands to the proxy, so the rules check its
// target, function and arguments exactly, and lets the call revert or return an arbitrary answer.
// Token balances are a ghost indexed by the number of proxy calls made so far, so every proxy call
// may move any balance arbitrarily, which covers every token and counterparty behaviour. Approvals
// made through ApproveLib reach the proxy like every other call, with arbitrary token answers, so
// both of its paths (direct, and reset-and-retry) are covered. Token decimals and the counterparty's
// proxy and CONTROLLER role are arbitrary per contract. That the proxy then forwards the calldata
// unchanged is proven by the ALMProxy spec (doCall).
//
// completeSwap has no role check: it is permissioned through its rate limit key, which includes
// the caller (the counterparty proxy). roleGated and adminIsConfigurationOnly are therefore re-run
// over every other function, and the completeSwap rules hold for any caller.

import "FacetBase.spec";

using CallDecoder as decoder;

// --- Methods block ---

methods {
    function getInitiateSwapRateLimitKey(address, address, address, address) external returns (bytes32) envfree;
    function getCompleteSwapRateLimitKey(address, address, address)          external returns (bytes32) envfree;

    function decoder.decodeCall(bytes)       external returns (uint256, bytes4, uint256, uint256, uint256) envfree;
    function decoder.isAcceptedAnswer(bytes) external returns (bool)                                      envfree;
    function decoder.isInvalidBool(bytes)    external returns (bool)                                      envfree;

    function _.doCall(address target, bytes data) external => cvlDoCall(target, data) expect bytes;

    // Counterparty and token reads (static calls)
    function _.proxy()                    external => counterpartyProxyOf(calledContract)          expect address;
    function _.CONTROLLER()               external => controllerRoleOf(calledContract)             expect bytes32;
    function _.decimals()                 external => decimalsOf(calledContract)                   expect uint8;
    function _.balanceOf(address account) external => balanceAt(calledContract, account, doCalls) expect uint256;
}

// --- Generic rules ---

use rule rateLimitCallsAreFacetCalls;
use rule allocatorRequiresRateLimit;
use rule noForbiddenCalls;
use rule noProxyDelegateCalls;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

rule roleGatedExcept_completeSwap(method f) filtered {
    f -> !f.isView && f.selector != sig:completeSwap(address, address, uint256).selector
} {
    checkRoleGated(f);
}

rule adminIsConfigurationOnlyExcept_completeSwap(method f) filtered {
    f -> !f.isView && f.selector != sig:completeSwap(address, address, uint256).selector
} {
    checkAdminIsConfigurationOnly(f);
}

// --- Definitions ---

definition APPROVE_SELECTOR()       returns bytes4 = to_bytes4(0x095ea7b3);  // approve(address,uint256)
definition TRANSFER_SELECTOR()      returns bytes4 = to_bytes4(0xa9059cbb);  // transfer(address,uint256)
definition TRANSFER_FROM_SELECTOR() returns bytes4 = to_bytes4(0x23b872dd);  // transferFrom(address,address,uint256)
definition COMPLETE_SWAP_SELECTOR() returns bytes4 = to_bytes4(0xd55ed608);  // swapAsset_completeSwap(address,address,uint256)

// _convertAmount: amount of assetFrom (dFrom decimals) as the 1:1 amount of assetTo (dTo decimals).
// 10 ** gap panics above 77 (10^78 does not fit in a uint256), scaling up reverts on overflow, and
// scaling down reverts when it would lose precision.
definition decimalsGap(uint8 dFrom, uint8 dTo) returns mathint =
    dFrom <= dTo ? dTo - dFrom : dFrom - dTo;

definition convertReverts(uint256 amount, uint8 dFrom, uint8 dTo) returns bool =
    decimalsGap(dFrom, dTo) > 77 ||
    (dFrom <= dTo && amount * (10 ^ decimalsGap(dFrom, dTo)) > max_uint256) ||
    (dFrom >  dTo && amount % (10 ^ decimalsGap(dFrom, dTo)) != 0);

// `result` is the conversion of `amount`. Stated without division: scaling down is exact whenever
// convertReverts does not hold, so result * 10^gap == amount pins result down.
definition isConverted(uint256 amount, uint8 dFrom, uint8 dTo, mathint result) returns bool =
    dFrom <= dTo ? result == amount * (10 ^ decimalsGap(dFrom, dTo))
                 : result * (10 ^ decimalsGap(dFrom, dTo)) == to_mathint(amount);

// --- Summaries ---

persistent ghost counterpartyProxyOf(address) returns address;
persistent ghost controllerRoleOf(address)    returns bytes32;
persistent ghost decimalsOf(address)          returns uint8;

// balanceAt(token, account, n): the balance after n proxy calls
persistent ghost balanceAt(address, address, mathint) returns uint256;

// Every call the facet asks the proxy to make, in order: target, calldata length, selector, first
// three argument words, the rate limit decreases and increases made before it, whether it
// reverted, and how its answer reads to the facet and ApproveLib.
persistent ghost mathint doCalls;
persistent ghost mapping(mathint => address) callTarget;
persistent ghost mapping(mathint => uint256) callLength;
persistent ghost mapping(mathint => bytes4)  callSelector;
persistent ghost mapping(mathint => uint256) callWord0;
persistent ghost mapping(mathint => uint256) callWord1;
persistent ghost mapping(mathint => uint256) callWord2;
persistent ghost mapping(mathint => mathint) callDecreasesBefore;
persistent ghost mapping(mathint => mathint) callIncreasesBefore;
persistent ghost mapping(mathint => bool)    callReverted;
persistent ghost mapping(mathint => bool)    callAnswerAccepted;
persistent ghost mapping(mathint => bool)    callAnswerInvalid;

// Any proxy call either reverts, or returns an arbitrary answer. Balances read after it are those
// of the next index of balanceAt, so they are arbitrary too.
function cvlDoCall(address target, bytes data) returns bytes {
    mathint i = doCalls;
    doCalls = doCalls + 1;

    uint256 length;
    bytes4  selector;
    uint256 word0;
    uint256 word1;
    uint256 word2;
    length, selector, word0, word1, word2 = decoder.decodeCall(data);

    callTarget[i]          = target;
    callLength[i]          = length;
    callSelector[i]        = selector;
    callWord0[i]           = word0;
    callWord1[i]           = word1;
    callWord2[i]           = word2;
    callDecreasesBefore[i] = rateLimitDecreases;
    callIncreasesBefore[i] = rateLimitIncreases;

    bool reverts;
    callReverted[i] = reverts;
    if (reverts) {
        revert("proxy call failed");
    }

    bytes answer;
    callAnswerAccepted[i] = decoder.isAcceptedAnswer(answer);
    callAnswerInvalid[i]  = decoder.isInvalidBool(answer);

    return answer;
}

// Call i was made; it reverted; it returned an answer the facet and ApproveLib accept; it returned
// a word that does not decode as a bool
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

// Only the two swap functions reach outside the facet. A function added later that calls out fails
// this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 =>
        f.selector == sig:initiateSwap(address, address, address, uint256).selector ||
        f.selector == sig:completeSwap(address, address, uint256).selector;
}

// --- View function correctness ---

// A limit configured for one (assetOut, counterparty proxy, counterparty controller, assetIn) cannot
// be spent on another
rule initiateSwapRateLimitKeys_distinct(
    address assetOut1, address proxy1, address controller1, address assetIn1,
    address assetOut2, address proxy2, address controller2, address assetIn2
) {
    assert assetOut1 != assetOut2 || proxy1 != proxy2 || controller1 != controller2 || assetIn1 != assetIn2 =>
        getInitiateSwapRateLimitKey(assetOut1, proxy1, controller1, assetIn1) !=
        getInitiateSwapRateLimitKey(assetOut2, proxy2, controller2, assetIn2);
}

// A limit configured for one (assetOut, counterparty proxy, assetIn) cannot be spent on another, in
// particular by another caller of completeSwap
rule completeSwapRateLimitKeys_distinct(
    address assetOut1, address proxy1, address assetIn1,
    address assetOut2, address proxy2, address assetIn2
) {
    assert assetOut1 != assetOut2 || proxy1 != proxy2 || assetIn1 != assetIn2 =>
        getCompleteSwapRateLimitKey(assetOut1, proxy1, assetIn1) !=
        getCompleteSwapRateLimitKey(assetOut2, proxy2, assetIn2);
}

// No key of one action is a key of the other
rule rateLimitKeys_actionsDistinct(
    address assetOut1, address proxy1, address controller1, address assetIn1,
    address assetOut2, address proxy2, address assetIn2
) {
    assert getInitiateSwapRateLimitKey(assetOut1, proxy1, controller1, assetIn1) !=
           getCompleteSwapRateLimitKey(assetOut2, proxy2, assetIn2);
}

// --- Allocator functions: initiateSwap ---

// The counterparty controller holds its proxy's CONTROLLER role. The initiate limit for this pair
// is charged with amountOut, and the reverse one replenished with amountIn (the 1:1 conversion of
// amountOut) when configured, before any proxy call. Then assetOut is approved to the counterparty
// proxy for amountOut, the counterparty controller is asked to completeSwap, the approval is reset,
// and exactly amountOut left and amountIn arrived over the completeSwap call and the reset.
//
// Each approval is one call, or three when the token's first answer is rejected, so the completeSwap
// call is call 1 or 3 and the run makes 3, 5 or 7 calls. Every one is checked at its index.
rule initiateSwap(address counterpartyController, address assetOut, address assetIn, uint256 amountOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address counterpartyProxy = counterpartyProxyOf(counterpartyController);
    uint8   decimalsOut       = decimalsOf(assetOut);
    uint8   decimalsIn        = decimalsOf(assetIn);
    bytes32 reverseKey        = getInitiateSwapRateLimitKey(assetIn, counterpartyProxy, counterpartyController, assetOut);
    bool    reverseConfigured = rateLimitMaxAmount(reverseKey) > 0;

    initiateSwap(e, counterpartyController, assetOut, assetIn, amountOut);

    mathint swapIndex  = accepted(0) ? 1 : 3;
    mathint resetIndex = swapIndex + 1;

    // amountIn: the amount the counterparty is asked for, which is the 1:1 conversion of amountOut
    mathint amountIn = callWord2[swapIndex];
    assert isConverted(amountOut, decimalsOut, decimalsIn, amountIn);

    // The counterparty controller is its proxy's controller
    assert hasRoleGhost(counterpartyProxy, controllerRoleOf(counterpartyProxy), counterpartyController);

    // Rate limits: the initiate limit charged with amountOut, and the reverse one replenished with
    // amountIn only when configured
    assert rateLimitDecreases  == 1;
    assert lastDecreasedKey    == getInitiateSwapRateLimitKey(assetOut, counterpartyProxy, counterpartyController, assetIn);
    assert lastDecreasedAmount == amountOut;
    assert rateLimitIncreases  == (reverseConfigured ? 1 : 0);
    assert reverseConfigured => lastIncreasedKey == reverseKey && lastIncreasedAmount == amountIn;

    // Every proxy call comes after the rate limit updates
    assert callDecreasesBefore[0] == rateLimitDecreases && callIncreasesBefore[0] == rateLimitIncreases;

    // Approval of assetOut to the counterparty proxy for amountOut: call 0, followed by approve(0)
    // and the approve again when its answer is rejected
    assert isApproveCall(0, assetOut, counterpartyProxy, amountOut);
    assert !accepted(0) =>
        isApproveCall(1, assetOut, counterpartyProxy, 0) && isApproveCall(2, assetOut, counterpartyProxy, amountOut);

    // Then counterpartyController.swapAsset_completeSwap(assetIn, assetOut, amountIn)
    assert callTarget[swapIndex]   == counterpartyController;
    assert callLength[swapIndex]   == 100;
    assert callSelector[swapIndex] == COMPLETE_SWAP_SELECTOR();
    assert callWord0[swapIndex]    == to_mathint(assetIn);
    assert callWord1[swapIndex]    == to_mathint(assetOut);

    // Then the approval reset to zero: call `resetIndex`, followed by two more approve(0) when its
    // answer is rejected, and nothing else
    assert isApproveCall(resetIndex, assetOut, counterpartyProxy, 0);
    assert !accepted(resetIndex) =>
        isApproveCall(resetIndex + 1, assetOut, counterpartyProxy, 0) &&
        isApproveCall(resetIndex + 2, assetOut, counterpartyProxy, 0);
    assert doCalls == (accepted(resetIndex) ? resetIndex + 1 : resetIndex + 3);

    // Exactly amountOut left and amountIn arrived, measured from the completeSwap call on
    assert balanceAt(assetOut, proxy, swapIndex) - balanceAt(assetOut, proxy, doCalls) == to_mathint(amountOut);
    assert balanceAt(assetIn,  proxy, doCalls)   - balanceAt(assetIn,  proxy, swapIndex) == amountIn;
}

// The two directions are stated separately. The first call of each approval is a low-level call,
// and when it reverts, ApproveLib copies the revert data into memory. The prover does not bound
// that data's size, so it can leave the free-memory pointer next to the 2^64 limit, and the next
// allocation then reverts. On chain, that much memory runs out of gas first. Reverts after such a
// caught failure are therefore allowed in the second direction.
rule initiateSwap_revert(address counterpartyController, address assetOut, address assetIn, uint256 amountOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address counterpartyProxy = counterpartyProxyOf(counterpartyController);
    uint8   decimalsOut       = decimalsOf(assetOut);
    uint8   decimalsIn        = decimalsOf(assetIn);
    uint256 status            = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);
    bool    isController      = hasRoleGhost(counterpartyProxy, controllerRoleOf(counterpartyProxy), counterpartyController);

    initiateSwap@withrevert(e, counterpartyController, assetOut, assetIn, amountOut);

    bool reverted = lastReverted;

    mathint swapIndex  = accepted(0) ? 1 : 3;
    mathint resetIndex = swapIndex + 1;
    bool    swapped    = made(swapIndex) && !callReverted[swapIndex];

    mathint amountOutSent    = balanceAt(assetOut, proxy, swapIndex) - balanceAt(assetOut, proxy, doCalls);
    mathint amountInReceived = balanceAt(assetIn,  proxy, doCalls)   - balanceAt(assetIn,  proxy, swapIndex);

    bool revert1  = e.msg.value > 0;
    bool revert2  = status == ENTERED();
    bool revert3  = !senderIsAllocator;
    bool revert4  = !isController;
    bool revert5  = convertReverts(amountOut, decimalsOut, decimalsIn);
    bool revert6  = approvalReverts(0);
    bool revert7  = failed(swapIndex);
    bool revert8  = swapped && approvalReverts(resetIndex);
    // A balance moving the wrong way underflows; either amount differing fails its require
    bool revert9  = swapped && amountOutSent != to_mathint(amountOut);
    bool revert10 = swapped && !isConverted(amountOut, decimalsOut, decimalsIn, amountInReceived);

    bool caughtFailure = failed(0) || (swapped && failed(resetIndex));

    // Each of these makes the call revert
    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 || revert9 || revert10 => reverted;
    // And nothing else does, except running out of memory after a caught failure
    assert reverted => revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 || revert9 || revert10 ||
                       caughtFailure;
}

// --- Counterparty functions: completeSwap ---

// For any caller: the complete limit keyed with the caller as the counterparty proxy is charged with
// amountOut, and the reverse one replenished with amountIn (the 1:1 conversion of amountOut) when
// configured, before any proxy call. Then amountIn of assetIn is pulled from the caller into the
// proxy and amountOut of assetOut sent to the caller, both answers accepted, and nothing else. With
// the keys distinct per caller, only a caller for which a limit is configured can swap.
rule completeSwap(address assetOut, address assetIn, uint256 amountOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address counterpartyProxy = e.msg.sender;
    uint8   decimalsOut       = decimalsOf(assetOut);
    uint8   decimalsIn        = decimalsOf(assetIn);
    bytes32 reverseKey        = getCompleteSwapRateLimitKey(assetIn, counterpartyProxy, assetOut);
    bool    reverseConfigured = rateLimitMaxAmount(reverseKey) > 0;

    completeSwap(e, assetOut, assetIn, amountOut);

    // amountIn: the amount pulled from the caller, which is the 1:1 conversion of amountOut
    mathint amountIn = callWord2[0];
    assert isConverted(amountOut, decimalsOut, decimalsIn, amountIn);

    // Rate limits
    assert rateLimitDecreases  == 1;
    assert lastDecreasedKey    == getCompleteSwapRateLimitKey(assetOut, counterpartyProxy, assetIn);
    assert lastDecreasedAmount == amountOut;
    assert rateLimitIncreases  == (reverseConfigured ? 1 : 0);
    assert reverseConfigured => lastIncreasedKey == reverseKey && lastIncreasedAmount == amountIn;

    // Every proxy call comes after the rate limit updates
    assert callDecreasesBefore[0] == rateLimitDecreases && callIncreasesBefore[0] == rateLimitIncreases;

    // Exactly two proxy calls
    assert doCalls == 2;

    // assetIn.transferFrom(caller, proxy, amountIn)
    assert callTarget[0]   == assetIn;
    assert callLength[0]   == 100;
    assert callSelector[0] == TRANSFER_FROM_SELECTOR();
    assert callWord0[0]    == to_mathint(counterpartyProxy);
    assert callWord1[0]    == to_mathint(proxy);
    assert accepted(0);

    // assetOut.transfer(caller, amountOut)
    assert callTarget[1]   == assetOut;
    assert callLength[1]   == 68;
    assert callSelector[1] == TRANSFER_SELECTOR();
    assert callWord0[1]    == to_mathint(counterpartyProxy);
    assert callWord1[1]    == amountOut;
    assert accepted(1);
}

// Both proxy calls are plain calls, so no revert is caught and the two directions hold together
rule completeSwap_revert(address assetOut, address assetIn, uint256 amountOut) {
    env e;

    setupRecorders();

    uint8   decimalsOut = decimalsOf(assetOut);
    uint8   decimalsIn  = decimalsOf(assetIn);
    uint256 status      = status();

    completeSwap@withrevert(e, assetOut, assetIn, amountOut);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = convertReverts(amountOut, decimalsOut, decimalsIn);
    bool revert4 = made(0) && !accepted(0);
    bool revert5 = made(1) && !accepted(1);

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}
