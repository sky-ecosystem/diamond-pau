// UniswapV3.spec
//
// UniswapV3Facet: the generic facet rules. Add facet specific summaries, filters or rules here.

import "FacetBase.spec";

methods {
    // Pure fixed-point math of the Uniswap libraries: the properties do not depend on the values,
    // and the non-linear arithmetic makes the vacuity checks of addLiquidity time out
    function TickMath.getSqrtRatioAtTick(int24) internal returns (uint160) => NONDET;
    function LiquidityAmounts.getLiquidityForAmounts(uint160, uint160, uint160, uint256, uint256) internal returns (uint128) => NONDET;
}

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;
