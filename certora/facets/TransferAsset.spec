// TransferAsset.spec
//
// TransferAssetFacet: the generic facet rules plus rules for its one action. The proxy call is
// summarised: the summary decodes the calldata the facet hands to the proxy, checking it is exactly
// transfer(destination, amount) on the asset, and returns an arbitrary answer, so every possible
// token answer is covered without a mock token. That the proxy then forwards this calldata to the
// asset unchanged is proven by the ALMProxy spec (doCall).

import "FacetBase.spec";

using TransferCallDecoder as decoder;

// --- Methods block ---

methods {
    function getTransferRateLimitKey(address, address) external returns (bytes32) envfree;

    function decoder.decodeTransfer(bytes)   external returns (bool, bytes4, uint256, uint256) envfree;
    function decoder.isAcceptedAnswer(bytes) external returns (bool)                             envfree;

    function _.doCall(address target, bytes data) external => cvlDoCall(target, data) expect bytes;
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

// IERC20.transfer(address,uint256)
definition ERC20_TRANSFER_SELECTOR() returns bytes4 = to_bytes4(0xa9059cbb);

// --- Proxy call summary ---

// What the facet asked the proxy to do, and how the call ended
persistent ghost mathint doCalls;
persistent ghost address doCallTarget;
persistent ghost bool    doCallWellFormed;
persistent ghost bytes4  doCallSelector;
persistent ghost uint256 doCallToWord;
persistent ghost uint256 doCallAmount;
persistent ghost bool    doCallBeforeDecrease;
persistent ghost bool    doCallReverted;
persistent ghost bool    answerAccepted;

// The proxy call either reverts (the token call failed) or returns an arbitrary answer
function cvlDoCall(address target, bytes data) returns bytes {
    doCalls              = doCalls + 1;
    doCallTarget         = target;
    doCallBeforeDecrease = rateLimitDecreases == 0;

    bool    wellFormed;
    bytes4  selector;
    uint256 toWord;
    uint256 amount;
    wellFormed, selector, toWord, amount = decoder.decodeTransfer(data);

    doCallWellFormed = wellFormed;
    doCallSelector   = selector;
    doCallToWord     = toWord;
    doCallAmount     = amount;

    bool reverts;
    doCallReverted = reverts;
    if (reverts) {
        revert("token call failed");
    }

    bytes answer;
    answerAccepted = decoder.isAcceptedAnswer(answer);
    return answer;
}

// --- External Calls Affected Rule ---

// Only transfer reaches outside the facet. FacetBase proves the facet never delegatecalls,
// callcodes or deploys, so a CALL is its only way out. A function added later that calls out fails
// this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 => f.selector == sig:transfer(address, address, uint256).selector;
}

// --- View function correctness ---

// A limit configured for one (asset, destination) pair cannot be spent on another: the rate limit
// configuration is the whitelist of destinations
rule rateLimitKeys_distinct(address asset1, address destination1, address asset2, address destination2) {
    assert asset1 != asset2 || destination1 != destination2 =>
        getTransferRateLimitKey(asset1, destination1) != getTransferRateLimitKey(asset2, destination2);
}

// --- Allocator functions: transfer ---

// The facet does not compare balances, so a fee-on-transfer token delivers less than `amount`
// while the full `amount` is consumed from the rate limit. That is by design.
rule transfer(address asset, address destination, uint256 amount) {
    env e;

    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require doCalls == 0;

    transfer(e, asset, destination, amount);

    // Rate limit: exactly one decrease, for this (asset, destination) pair, by the amount
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getTransferRateLimitKey(asset, destination);
    assert lastDecreasedAmount == amount;

    // Proxy call: exactly one, after the decrease, on the asset, of transfer(destination, amount)
    assert doCalls == 1;
    assert !doCallBeforeDecrease;
    assert doCallTarget == asset;
    assert doCallWellFormed;
    assert doCallSelector == ERC20_TRANSFER_SELECTOR();
    assert doCallToWord   == to_mathint(destination);
    assert doCallAmount   == amount;

    // The token's answer was accepted
    assert answerAccepted;
}

rule transfer_revert(address asset, address destination, uint256 amount) {
    env e;

    require doCalls == 0 && !doCallReverted && !answerAccepted;

    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    transfer@withrevert(e, asset, destination, amount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = doCallReverted;
    bool revert5 = doCalls > 0 && !doCallReverted && !answerAccepted;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}
