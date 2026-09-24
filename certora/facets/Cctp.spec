// Cctp.spec
//
// CCTPFacet: the generic facet rules plus rules for each external function. The real ALMProxy is
// in the scene and the immutable `cctp` and `usdc` are linked to mocks that record what they
// receive, so that every effect of the facet is pinned to its arguments, to the stored domain
// parameters and to the rate limit keys it consumes.

import "FacetBase.spec";

using ALMProxy  as almProxy;
using MockERC20 as usdcToken;
using MockCCTP  as cctpMessenger;

// --- Methods block ---

methods {
    // CCTPFacet constants and immutables
    function DESTINATION_CALLER()     external returns (bytes32) envfree;
    function MIN_FINALITY_THRESHOLD() external returns (uint32)  envfree;
    function cctp()                   external returns (address) envfree;
    function usdc()                   external returns (address) envfree;

    // CCTPFacet view functions
    function toCCTPRateLimitKey()             external returns (bytes32) envfree;
    function getToDomainRateLimitKey(uint32)  external returns (bytes32) envfree;
    function getDomainParameters(uint32)      external returns (bytes32, uint32, uint32) envfree;

    // ALMProxy constant
    function almProxy.CONTROLLER() external returns (bytes32) envfree;

    // ALMProxy: the facet reaches it through an address in shared storage, resolved to the real
    // contract so that the forwarded calls are observed
    function _.doCall(address target, bytes data)                         external => DISPATCHER(true);
    function _.doCallWithValue(address target, bytes data, uint256 value) external => DISPATCHER(true);
    function _.doDelegateCall(address target, bytes data)                 external => DISPATCHER(true);

    // Calls forwarded by the proxy are dispatched to the mocks. A selector they do not model
    // reaches their fallback and is counted as an unexpected call; a call to any other address is
    // observed by the CALL hook and modelled as having no effect.
    unresolved external in ALMProxy._ => DISPATCH(optimistic=false, use_fallback=true) [
        MockERC20._,
        MockCCTP._
    ] default NONDET;

    // CCTP metadata read directly by the facet (static calls), answered by the messenger mock.
    // `localMinter()` is called on the linked `cctp` and resolves statically; the burn limit is
    // then read on the address it returned, which is only known at run time, so that call is
    // dispatched by address to the mock instead of being havoced.
    function cctpMessenger.burnLimitsPerMessage(address) external returns (uint256) envfree;
    function _.burnLimitsPerMessage(address)             external => DISPATCHER(true);
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// --- Definitions ---

definition ONE_HUNDRED_PERCENT() returns mathint = 10000;

// sky.pau.storage.CCTPFacet.v1
definition mintRecipient(uint32 domain) returns bytes32 = currentContract.ext_sky_pau_storage_CCTPFacet_v1.domainParameters[domain].mintRecipient;
definition minFeeCapRate(uint32 domain) returns uint32  = currentContract.ext_sky_pau_storage_CCTPFacet_v1.domainParameters[domain].minFeeCapRate;
definition maxFeeCapRate(uint32 domain) returns uint32  = currentContract.ext_sky_pau_storage_CCTPFacet_v1.domainParameters[domain].maxFeeCapRate;

// The burn limit the facet reads for USDC
definition usdcBurnLimit() returns uint256 = cctpMessenger.burnLimitsPerMessage(usdcToken);

// Number of depositForBurn calls for `amount` under the loop bound of the conf (loop_iter 2)
definition expectedDeposits(uint256 amount, uint256 burnLimit) returns mathint =
    amount == 0 ? 0 : (amount <= burnLimit ? 1 : 2);

// --- Setup ---

// The proxy in shared storage is the ALMProxy of the scene and the facet is its controller
function setupProxy() {
    require proxySlot() == almProxy;
    require almProxy._roles[almProxy.CONTROLLER()].hasRole[currentContract];
}

// No interaction recorded yet, neither in the ghosts nor in the mocks
function setupRecorders() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require forall bytes32 key. decreasesOfKey[key] == 0 && decreasedByKey[key] == 0;
    require forall address target. !sceneCalledTarget[target];
    require forall address target. !calledBeforeDecrease[target];
    require facetCalls == 0 && facetDelegateCalls == 0 && facetCreates == 0;
    require sceneDelegateCalls == 0 && sceneCreates == 0 && sceneValueCalls == 0;

    require usdcToken.unexpectedCalls == 0 && usdcToken.approveCalls == 0;
    require forall address spender. usdcToken.approvalsTo[spender] == 0;
    require forall uint256 amount. !usdcToken.approvedAmountSeen[amount];
    require cctpMessenger.unexpectedCalls == 0 && cctpMessenger.depositCalls == 0;
    require cctpMessenger.depositedTotal == 0;
}

// --- Storage Affected Rule ---

// The domain parameters are only written by setDomainParameters, and only for its domain
rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    uint32 anyDomain;

    bytes32 mintRecipientBefore = mintRecipient(anyDomain);
    uint32  minFeeCapRateBefore = minFeeCapRate(anyDomain);
    uint32  maxFeeCapRateBefore = maxFeeCapRate(anyDomain);

    f(e, args);

    assert mintRecipient(anyDomain) != mintRecipientBefore =>
        f.selector == sig:setDomainParameters(uint32, bytes32, uint32, uint32).selector;
    assert minFeeCapRate(anyDomain) != minFeeCapRateBefore =>
        f.selector == sig:setDomainParameters(uint32, bytes32, uint32, uint32).selector;
    assert maxFeeCapRate(anyDomain) != maxFeeCapRateBefore =>
        f.selector == sig:setDomainParameters(uint32, bytes32, uint32, uint32).selector;
}

// --- View function correctness ---

rule constants() {
    assert DESTINATION_CALLER()     == to_bytes32(0);
    assert MIN_FINALITY_THRESHOLD() == 2000;
}

rule getDomainParameters_correctness(uint32 destinationDomain) {
    bytes32 recipient;
    uint32  minRate;
    uint32  maxRate;
    recipient, minRate, maxRate = getDomainParameters(destinationDomain);

    assert recipient == mintRecipient(destinationDomain);
    assert minRate   == minFeeCapRate(destinationDomain);
    assert maxRate   == maxFeeCapRate(destinationDomain);
}

// Rate limit keys never alias: each domain has its own limit, distinct from the global one
rule rateLimitKeys_distinct(uint32 domain1, uint32 domain2) {
    assert getToDomainRateLimitKey(domain1) != toCCTPRateLimitKey();
    assert domain1 != domain2 => getToDomainRateLimitKey(domain1) != getToDomainRateLimitKey(domain2);
}

// --- Admin functions: setDomainParameters ---

rule setDomainParameters(uint32 destinationDomain, bytes32 recipient, uint32 minRate, uint32 maxRate) {
    env e;

    setupProxy();
    setupRecorders();

    uint32 otherDomain;
    require otherDomain != destinationDomain;

    bytes32 otherRecipientBefore = mintRecipient(otherDomain);
    uint32  otherMinRateBefore   = minFeeCapRate(otherDomain);
    uint32  otherMaxRateBefore   = maxFeeCapRate(otherDomain);

    setDomainParameters(e, destinationDomain, recipient, minRate, maxRate);

    // The parameters of the domain are exactly the given ones
    assert mintRecipient(destinationDomain) == recipient;
    assert minFeeCapRate(destinationDomain) == minRate;
    assert maxFeeCapRate(destinationDomain) == maxRate;
    // Other domains are untouched
    assert mintRecipient(otherDomain) == otherRecipientBefore;
    assert minFeeCapRate(otherDomain) == otherMinRateBefore;
    assert maxFeeCapRate(otherDomain) == otherMaxRateBefore;
    // Pure configuration: nothing is called, nothing is decreased
    assert facetCalls == 0 && facetDelegateCalls == 0 && facetCreates == 0;
    assert rateLimitDecreases == 0 && rateLimitIncreases == 0;
    assert forall address target. !sceneCalledTarget[target];
}

rule setDomainParameters_revert(uint32 destinationDomain, bytes32 recipient, uint32 minRate, uint32 maxRate) {
    env e;

    uint256 statusBefore  = status();
    bool    senderIsAdmin = isAdmin(e.msg.sender);

    setDomainParameters@withrevert(e, destinationDomain, recipient, minRate, maxRate);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = recipient == to_bytes32(0);
    bool revert5 = minRate > maxRate;
    bool revert6 = maxRate >= ONE_HUNDRED_PERCENT();

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6;
}

// --- Allocator functions: transfer ---

rule transfer(uint256 amount, uint32 destinationDomain, uint64 feeCapRate) {
    env e;

    setupProxy();
    setupRecorders();

    uint256 burnLimit = usdcBurnLimit();
    bytes32 recipient = mintRecipient(destinationDomain);
    address rateLimits = rateLimitsSlot();

    // Within the loop bound of the conf: at most two chunks
    require amount <= 2 * burnLimit;

    uint32 otherDomain;
    require otherDomain != destinationDomain;
    bytes32 otherKey = getToDomainRateLimitKey(otherDomain);

    transfer(e, amount, destinationDomain, feeCapRate);

    // Rate limits: the global key and the domain key are each decreased once by the full amount,
    // nothing else is decreased and nothing is increased
    assert rateLimitDecreases == 2;
    assert rateLimitIncreases == 0;
    assert decreasesOfKey[toCCTPRateLimitKey()]                       == 1;
    assert decreasedByKey[toCCTPRateLimitKey()]                       == amount;
    assert decreasesOfKey[getToDomainRateLimitKey(destinationDomain)] == 1;
    assert decreasedByKey[getToDomainRateLimitKey(destinationDomain)] == amount;
    assert decreasesOfKey[otherKey]                                   == 0;

    // Burns: the whole amount, in chunks bounded by the burn limit, every chunk to the configured
    // recipient of this domain, in USDC, relayable by anyone, at standard finality, with the fee
    // cap derived from feeCapRate, and only after the rate limits were consumed
    assert cctpMessenger.depositCalls   == expectedDeposits(amount, burnLimit);
    assert cctpMessenger.depositedTotal == amount;
    uint256 i;
    require i < cctpMessenger.depositCalls;
    assert cctpMessenger.amounts[i]               <= burnLimit;
    assert cctpMessenger.destinationDomains[i]    == destinationDomain;
    assert cctpMessenger.mintRecipients[i]        == recipient;
    assert cctpMessenger.burnTokens[i]            == usdcToken;
    assert cctpMessenger.destinationCallers[i]    == to_bytes32(0);
    assert cctpMessenger.minFinalityThresholds[i] == 2000;
    assert cctpMessenger.maxFees[i]               == cctpMessenger.amounts[i] * feeCapRate / ONE_HUNDRED_PERCENT();
    assert !calledBeforeDecrease[almProxy];

    // Approvals: USDC to the messenger only, for the amount then zero
    assert usdcToken.approveCalls == 2;
    assert forall address spender. usdcToken.approvalsTo[spender] > 0 => spender == cctpMessenger;
    assert forall uint256 approved. usdcToken.approvedAmountSeen[approved] => approved == amount || approved == 0;
    assert usdcToken.lastApprovedAmount == 0;

    // Nothing else is asked of the token or the messenger, no ETH moves, nothing is delegatecalled
    // or deployed, and every call in the scene targets the proxy, the rate limits, USDC or CCTP
    assert usdcToken.unexpectedCalls     == 0;
    assert cctpMessenger.unexpectedCalls == 0;
    assert sceneValueCalls    == 0;
    assert sceneDelegateCalls == 0;
    assert sceneCreates       == 0;
    assert forall address target. sceneCalledTarget[target] =>
        target == almProxy || target == rateLimits || target == usdcToken || target == cctpMessenger;
}

// Exhaustive within the model: the rate limits are summarised as never reverting (a real
// RateLimits reverts when the amount exceeds the current limit), the mocks never revert, and the
// loop is bounded to two chunks.
rule transfer_revert(uint256 amount, uint32 destinationDomain, uint64 feeCapRate) {
    env e;

    setupProxy();

    uint256 burnLimit = usdcBurnLimit();
    require burnLimit > 0;
    require amount <= 2 * burnLimit;

    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);
    bytes32 recipient         = mintRecipient(destinationDomain);
    uint32  minRate           = minFeeCapRate(destinationDomain);
    uint32  maxRate           = maxFeeCapRate(destinationDomain);

    // The largest chunk is min(amount, burnLimit); its fee computation must not overflow
    mathint largestChunk = amount <= burnLimit ? amount : burnLimit;

    transfer@withrevert(e, amount, destinationDomain, feeCapRate);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = recipient == to_bytes32(0);
    bool revert5 = feeCapRate < minRate;
    bool revert6 = feeCapRate > maxRate;
    bool revert7 = largestChunk * feeCapRate > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7;
}
