// psm.spec
//
// PSMFacet: the generic facet rules. `swapUSDCToUSDS` refills the LitePSM with a direct call to
// `fill()` when the swap has to be chunked, so the generic external calls rule is replaced for
// that function by one that pins the extra call to exactly that target and selector.

import "general.spec";

// --- Methods block ---

methods {
    // PSMFacet immutable getter
    function psm() external returns (address) envfree;

    // The PSM refill, the one state changing call made outside the proxy
    function _.fill() external => cvlFill(calledContract) expect uint256;
}

// --- Ghosts and summaries ---

persistent ghost mathint fillCalls;
persistent ghost address fillTarget;

function cvlFill(address target) returns uint256 {
    fillCalls  = fillCalls + 1;
    fillTarget = target;
    uint256 wad;
    return wad;
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// The generic external calls check over every function but swapUSDCToUSDS, which is covered by its own
// rule below
rule externalCallsOnlyToProxyAndRateLimitsExcept_swapUSDCToUSDS(method f) filtered {
    f -> !f.isView && f.selector != sig:swapUSDCToUSDS(uint256).selector
} {
    checkExternalCallsOnlyToProxyAndRateLimits(f);
}

// --- swapUSDCToUSDS ---

// Besides the proxy and the rate limits, swapUSDCToUSDS only calls the PSM, and only to refill
// it. Nothing is delegatecalled or deployed.
rule swapUSDCToUSDS_externalCalls(uint256 usdcAmount) {
    env e;

    require forall address a. !facetCalledTarget[a];
    require facetDelegateCalls == 0 && facetCreates == 0;
    require fillCalls == 0;

    address proxy      = proxySlot();
    address rateLimits = rateLimitsSlot();
    address psm_       = psm();

    swapUSDCToUSDS(e, usdcAmount);

    assert forall address a. facetCalledTarget[a] => a == proxy || a == rateLimits || a == psm_;
    assert fillCalls > 0 => fillTarget == psm_;
    assert facetDelegateCalls == 0;
    assert facetCreates       == 0;
}
