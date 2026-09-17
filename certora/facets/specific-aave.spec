// AaveFacet.spec
//
// Facet specific specification: pins every external effect of each allocator action to its
// arguments and to the rate limit key it consumes, so that no action hides a call to another
// contract, another amount, or another beneficiary. The real ALMProxy is in the scene so that
// the calls it forwards are observed with their target and arguments.

using ALMProxy     as almProxy;
using MockERC20    as underlyingToken;
using MockAavePool as aavePool;

// --- Methods block ---

methods {
    // AaveFacet view functions
    function getMaxSlippage(address)                          external returns (uint256) envfree;
    function getDepositRateLimitKey(address, address, address) external returns (bytes32) envfree;
    function getWithdrawRateLimitKey(address, address)         external returns (bytes32) envfree;

    // ALMProxy constants
    function almProxy.CONTROLLER() external returns (bytes32) envfree;

    // AccessControls (address in shared namespaced storage, cannot be linked)
    function _.hasRole(bytes32 role, address account) external => hasRoleGhost(role, account) expect bool;

    // ALMProxy: the facet reaches it through an address in shared storage, resolved to the real
    // contract so that the forwarded calls are observed
    function _.doCall(address target, bytes data)                         external => DISPATCHER(true);
    function _.doCallWithValue(address target, bytes data, uint256 value) external => DISPATCHER(true);
    function _.doDelegateCall(address target, bytes data)                 external => DISPATCHER(true);

    // RateLimits
    function _.triggerRateLimitDecrease(bytes32 key, uint256 amount) external => cvlTriggerRateLimitDecrease(key, amount) expect uint256;
    function _.triggerRateLimitIncrease(bytes32 key, uint256 amount) external => cvlTriggerRateLimitIncrease(key, amount) expect uint256;

    // aToken metadata: pure functions of the aToken address
    function _.POOL()                      external => poolOf(calledContract)       expect address;
    function _.UNDERLYING_ASSET_ADDRESS()  external => underlyingOf(calledContract) expect address;

    // Calls forwarded by the proxy: their selector is only known at run time, so they are
    // dispatched to the mocks, which record the arguments. A selector the mocks do not model
    // reaches their fallback and is counted as an unexpected call. A call to any other address
    // is not pruned (optimistic=false) but havoced, so that the CALL hook still observes it.
    unresolved external in ALMProxy._ => DISPATCH(optimistic=false, use_fallback=true) [
        MockERC20._,
        MockAavePool._
    ] default HAVOC_ECF;

    function _.balanceOf(address) external => NONDET;
}

// --- Ghosts ---

persistent ghost hasRoleGhost(bytes32, address) returns bool;
persistent ghost poolOf(address)                returns address;
persistent ghost underlyingOf(address)          returns address;

// Rate limits
persistent ghost mathint rateLimitDecreases;
persistent ghost mathint rateLimitIncreases;
persistent ghost bytes32 decreasedKey;
persistent ghost uint256 decreasedAmount;

// Set when the pool is called before the rate limit was consumed
persistent ghost bool poolCalledBeforeDecrease;

// Every non-static external interaction in the scene
persistent ghost mapping(address => bool) calledTarget;
persistent ghost mathint delegateCalls;
persistent ghost mathint creates;

// --- Summaries ---

function cvlTriggerRateLimitDecrease(bytes32 key, uint256 amount) returns uint256 {
    rateLimitDecreases = rateLimitDecreases + 1;
    decreasedKey       = key;
    decreasedAmount    = amount;
    uint256 newLimit;
    return newLimit;
}

function cvlTriggerRateLimitIncrease(bytes32 key, uint256 amount) returns uint256 {
    rateLimitIncreases = rateLimitIncreases + 1;
    uint256 newLimit;
    return newLimit;
}

// --- Hooks ---

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    calledTarget[addr] = true;
    if (addr == aavePool && rateLimitDecreases == 0) {
        poolCalledBeforeDecrease = true;
    }
}

hook CALLCODE(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    calledTarget[addr] = true;
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegateCalls = delegateCalls + 1;
}

hook CREATE1(uint value, uint offset, uint length) address v {
    creates = creates + 1;
}

hook CREATE2(uint value, uint offset, uint length, bytes32 salt) address v {
    creates = creates + 1;
}

// --- Definitions ---

// sky.pau.storage.SharedController
definition proxySlot()      returns address = currentContract.ext_sky_pau_storage_SharedController.proxy;
definition rateLimitsSlot() returns address = currentContract.ext_sky_pau_storage_SharedController.rateLimits;

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
function setupGhosts() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require !poolCalledBeforeDecrease;
    require forall address target. !calledTarget[target];
    require delegateCalls == 0 && creates == 0;

    require underlyingToken.unexpectedCalls == 0 && underlyingToken.approveCalls == 0;
    require forall address spender. underlyingToken.approvalsTo[spender] == 0;
    require forall uint256 amount. !underlyingToken.approvedAmountSeen[amount];
    require aavePool.unexpectedCalls == 0 && aavePool.supplyCalls == 0;
}

// --- deposit ---

rule deposit(address aToken, uint256 amount) {
    env e;

    setupProxy();
    setupGhosts();
    setupAToken(aToken);

    address pool       = poolOf(aToken);
    address underlying = underlyingOf(aToken);
    address rateLimits = rateLimitsSlot();

    deposit(e, aToken, amount);

    // Rate limit: exactly one decrease, for the deposit key of this aToken, pool and underlying,
    // by the deposited amount, and no increase
    assert rateLimitDecreases == 1;
    assert rateLimitIncreases == 0;
    assert decreasedKey       == getDepositRateLimitKey(aToken, pool, underlying);
    assert decreasedAmount    == amount;

    // Supply: exactly one, on the pool of the aToken, of the underlying, for the same amount,
    // on behalf of the proxy, and only after the rate limit was consumed
    assert aavePool.supplyCalls        == 1;
    assert aavePool.suppliedAsset      == underlying;
    assert aavePool.suppliedAmount     == amount;
    assert aavePool.suppliedOnBehalfOf == almProxy;
    assert !poolCalledBeforeDecrease;

    // Approvals: only to the pool, only for the amount or zero, cleared at the end
    assert forall address spender. underlyingToken.approvalsTo[spender] > 0 => spender == pool;
    assert forall uint256 approved. underlyingToken.approvedAmountSeen[approved] => approved == amount || approved == 0;
    assert underlyingToken.approveCalls       >= 2;
    assert underlyingToken.lastApprovedAmount == 0;

    // Nothing else is asked of the token or the pool
    assert underlyingToken.unexpectedCalls == 0;
    assert aavePool.unexpectedCalls        == 0;

    // No other interaction: every call in the scene targets the proxy, the rate limits, the pool
    // or the underlying, and nothing is delegatecalled or deployed
    assert forall address target. calledTarget[target] =>
        target == almProxy || target == rateLimits || target == pool || target == underlying;
    assert delegateCalls == 0;
    assert creates       == 0;
}
