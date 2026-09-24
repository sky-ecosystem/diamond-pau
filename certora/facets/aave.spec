// Aave.spec
//
// AaveFacet: the generic facet rules plus rules that pin every external effect of each allocator
// action to its arguments and to the rate limit key it consumes, so that no action hides a call
// to another contract, another amount, or another beneficiary. The real ALMProxy is in the scene
// so that the calls it forwards are observed with their target and arguments; the generic rules
// keep holding because their counters only see calls issued by the facet itself.

import "FacetBase.spec";

using ALMProxy     as almProxy;
using MockERC20    as underlyingToken;
using MockAavePool as aavePool;

// --- Methods block ---

methods {
    // AaveFacet view functions
    function getMaxSlippage(address)                           external returns (uint256) envfree;
    function getDepositRateLimitKey(address, address, address) external returns (bytes32) envfree;
    function getWithdrawRateLimitKey(address, address)         external returns (bytes32) envfree;

    // ALMProxy constants
    function almProxy.CONTROLLER() external returns (bytes32) envfree;

    // ALMProxy: the facet reaches it through an address in shared storage, resolved to the real
    // contract so that the forwarded calls are observed
    function _.doCall(address target, bytes data)                         external => DISPATCHER(true);
    function _.doCallWithValue(address target, bytes data, uint256 value) external => DISPATCHER(true);
    function _.doDelegateCall(address target, bytes data)                 external => DISPATCHER(true);

    // Calls forwarded by the proxy: their selector is only known at run time, so they are
    // dispatched to the mocks, which record the arguments. A selector the mocks do not model
    // reaches their fallback and is counted as an unexpected call. A call to any other address
    // is not pruned (optimistic=false): it is still observed by the CALL hook, and modelled as
    // having no effect (NONDET) rather than havocing, since a havoc relative to the proxy would
    // rewrite the facet's own storage and break the generic rules for reasons unrelated to the
    // facet's code.
    unresolved external in ALMProxy._ => DISPATCH(optimistic=false, use_fallback=true) [
        MockERC20._,
        MockAavePool._
    ] default NONDET;

    // aToken metadata: pure functions of the aToken address
    function _.POOL()                     external => poolOf(calledContract)       expect address;
    function _.UNDERLYING_ASSET_ADDRESS() external => underlyingOf(calledContract) expect address;

    function _.balanceOf(address) external => NONDET;
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule allocatorRequiresRateLimit;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// --- Ghosts ---

persistent ghost poolOf(address)       returns address;
persistent ghost underlyingOf(address) returns address;

// --- Setup ---

// The proxy in shared storage is the ALMProxy of the scene and the facet is its controller
function setupProxy() {
    require proxySlot() == almProxy;
    require almProxy._roles[almProxy.CONTROLLER()].hasRole[currentContract];
}

// The mocks play the pool and the underlying of the aToken. Calls to any other address are
// still observed by the CALL hook and rejected by the target assertion.
function setupAToken(address aToken) {
    require poolOf(aToken)       == aavePool;
    require underlyingOf(aToken) == underlyingToken;
}

// No interaction recorded yet, neither in the ghosts nor in the mocks
function setupRecorders() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require forall address target. !sceneCalledTarget[target];
    require forall address target. !calledBeforeDecrease[target];
    require sceneDelegateCalls == 0 && sceneCreates == 0;

    require underlyingToken.unexpectedCalls == 0 && underlyingToken.approveCalls == 0;
    require forall address spender. underlyingToken.approvalsTo[spender] == 0;
    require forall uint256 amount. !underlyingToken.approvedAmountSeen[amount];
    require aavePool.unexpectedCalls == 0 && aavePool.supplyCalls == 0;
}

// --- deposit ---

rule deposit(address aToken, uint256 amount) {
    env e;

    setupProxy();
    setupRecorders();
    setupAToken(aToken);

    address pool       = poolOf(aToken);
    address underlying = underlyingOf(aToken);
    address rateLimits = rateLimitsSlot();

    deposit(e, aToken, amount);

    // Rate limit: exactly one decrease, for the deposit key of this aToken, pool and underlying,
    // by the deposited amount, and no increase
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == getDepositRateLimitKey(aToken, pool, underlying);
    assert lastDecreasedAmount == amount;

    // Supply: exactly one, of the underlying, for the same amount, on behalf of the proxy, and
    // only after the rate limit was consumed
    assert aavePool.supplyCalls        == 1;
    assert aavePool.suppliedAsset      == underlying;
    assert aavePool.suppliedAmount     == amount;
    assert aavePool.suppliedOnBehalfOf == almProxy;
    assert !calledBeforeDecrease[aavePool];

    // Approvals: only to the pool, only for the amount or zero, cleared at the end
    assert forall address spender. underlyingToken.approvalsTo[spender] > 0 => spender == pool;
    assert forall uint256 approved. underlyingToken.approvedAmountSeen[approved] => approved == amount || approved == 0;
    assert underlyingToken.approveCalls       >= 2;
    assert underlyingToken.lastApprovedAmount == 0;

    // Nothing else is asked of the token or the pool
    assert underlyingToken.unexpectedCalls == 0;
    assert aavePool.unexpectedCalls        == 0;

    // No other interaction anywhere in the scene: every call targets the proxy, the rate limits,
    // the pool or the underlying, and nothing is delegatecalled or deployed
    assert forall address target. sceneCalledTarget[target] =>
        target == almProxy || target == rateLimits || target == pool || target == underlying;
    assert sceneDelegateCalls == 0;
    assert sceneCreates       == 0;
}
