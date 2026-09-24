// Pendle.spec
//
// PendleFacet: the generic facet rules. `redeem` refreshes the PY index with a direct call to the
// YT contract before redeeming, so the generic external calls rule is replaced for that function
// by one that pins the extra call to exactly that target and selector.

import "FacetBase.spec";

// --- Methods block ---

methods {
    // Market metadata: pure functions of the market address
    function _.readTokens() external => cvlReadTokens(calledContract) expect (address, address, address);

    // The PY index refresh, the one state changing call made outside the proxy
    function _.pyIndexCurrent() external => cvlPyIndexCurrent(calledContract) expect uint256;
}

// --- Ghosts and summaries ---

persistent ghost syOf(address) returns address;
persistent ghost ptOf(address) returns address;
persistent ghost ytOf(address) returns address;

persistent ghost mathint pyIndexCurrentCalls;
persistent ghost address pyIndexCurrentTarget;

function cvlReadTokens(address market) returns (address, address, address) {
    return (syOf(market), ptOf(market), ytOf(market));
}

function cvlPyIndexCurrent(address target) returns uint256 {
    pyIndexCurrentCalls  = pyIndexCurrentCalls + 1;
    pyIndexCurrentTarget = target;
    uint256 index;
    return index;
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// externalCallsOnlyToProxyAndRateLimits is not used: redeem is the only non-view function of
// this facet and it is covered by redeem_externalCalls below. A parametric rule whose filter
// leaves no method fails with "could not find a match for method parameter f".

// --- redeem ---

// Besides the proxy and the rate limits, redeem only calls the YT token of the market, exactly
// once, to refresh its PY index. Nothing is delegatecalled or deployed.
rule redeem_externalCalls(address market, uint256 pyAmountIn, uint256 minAmountOut) {
    env e;

    require forall address a. !facetCalledTarget[a];
    require facetDelegateCalls == 0 && facetCreates == 0;
    require pyIndexCurrentCalls == 0;

    address proxy      = proxySlot();
    address rateLimits = rateLimitsSlot();
    address yt         = ytOf(market);

    redeem(e, market, pyAmountIn, minAmountOut);

    assert forall address a. facetCalledTarget[a] => a == proxy || a == rateLimits || a == yt;
    assert pyIndexCurrentCalls  == 1;
    assert pyIndexCurrentTarget == yt;
    assert facetDelegateCalls   == 0;
    assert facetCreates         == 0;
}
