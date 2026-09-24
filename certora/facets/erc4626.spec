// Erc4626.spec
//
// ERC4626Facet: the generic facet rules. Add facet specific summaries, filters or rules here.

import "FacetBase.spec";

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;
