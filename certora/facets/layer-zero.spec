// layer-zero.spec
//
// LayerZeroFacet: the generic facet rules. Add facet specific summaries, filters or rules here.

import "general.spec";

// --- Methods block ---

methods {
    // quoteTransfer reaches the OFT through a low-level staticcall to the proxy and abi.decodes
    // the returned bytes. The Prover's default havoc for an unresolved low-level call yields an
    // empty return buffer, so the decode always reverts and `transfer` has no reachable success
    // path. A NONDET summary returns arbitrary, decodable bytes instead. The call is static and
    // therefore invisible to the external call counters either way.
    function _.doCall(address target, bytes data) external => NONDET;

    // OptionsBuilder checks the option type with an unaligned 2-byte memory read (BytesLib.toUint16
    // at offset 0 of a 2-byte array), which the default memory model does not resolve. The read is
    // left free so that the type check cannot block every path of `transfer`.
    function BytesLib.toUint16(bytes memory, uint256) internal returns (uint16) => NONDET;
}

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;
