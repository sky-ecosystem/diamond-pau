// DualPool.spec
//
// DualPoolFacet: the generic facet rules. Add facet specific summaries, filters or rules here.

import "FacetBase.spec";

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule rateLimitCallsAreFacetCalls;
use rule allocatorRequiresRateLimit;
use rule noForbiddenCalls;
use rule noProxyDelegateCalls;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;
