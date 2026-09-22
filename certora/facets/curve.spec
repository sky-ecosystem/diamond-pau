// curve.spec
//
// CurveFacet: the generic facet rules. Add facet specific summaries, filters or rules here.

import "general.spec";

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;
