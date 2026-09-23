// Facet.spec
//
// Generic specification shared by every facet. It only refers to the facet through parametric
// methods, so the same file is verified against each facet with its own .conf.

// --- Methods block ---

methods {
    // Facet constants
    function DEFAULT_ADMIN_ROLE() external returns (bytes32) envfree;
    function ALLOCATOR_ROLE()     external returns (bytes32) envfree;

    // AccessControls: the address lives in shared namespaced storage and cannot be linked, so its
    // answer is modelled by a ghost, which keeps every role combination reachable.
    function _.hasRole(bytes32 role, address account) external => hasRoleGhost(role, account) expect bool;

    // RateLimits: every interaction is recorded. The configured maxAmount of a key is a ghost so
    // that a rule can consider the state in which no rate limit is configured at all.
    function _.triggerRateLimitDecrease(bytes32 key, uint256 amount) external => cvlTriggerRateLimitDecrease(key, amount) expect uint256;
    function _.triggerRateLimitIncrease(bytes32 key, uint256 amount) external => cvlTriggerRateLimitIncrease(key, amount) expect uint256;
    function _.getRateLimitData(bytes32 key)                         external => cvlGetRateLimitData(key)                  expect IRateLimits.RateLimitData;
    function _.getCurrentRateLimit(bytes32 key)                      external => cvlGetCurrentRateLimit(key)               expect uint256;

    // ALMProxy: not summarised here. Calls to it are observed by the opcode hooks below, which
    // lets a facet specific spec put the real ALMProxy in the scene and still reuse these rules.
}

// --- Ghosts ---

persistent ghost hasRoleGhost(bytes32, address) returns bool;

// Configured maxAmount per rate limit key
persistent ghost rateLimitMaxAmount(bytes32) returns uint256;

persistent ghost mathint rateLimitDecreases;
persistent ghost mathint rateLimitIncreases;
persistent ghost mathint rateLimitReads;
persistent ghost bytes32 lastDecreasedKey;
persistent ghost uint256 lastDecreasedAmount;
persistent ghost mapping(bytes32 => mathint) decreasesOfKey;   // number of decreases per key
persistent ghost mapping(bytes32 => mathint) decreasedByKey;   // total amount decreased per key

// Every non-static external interaction, recorded at the opcode level so that nothing escapes
// the summaries above (any proxy entry point, other contracts, delegatecalls, deployments).
// The `facet*` ghosts only count what the facet itself issues (executingContract is the facet);
// the `scene*` ghosts count every contract in the scene, e.g. what the proxy forwards.
persistent ghost mathint facetCalls;
persistent ghost mathint facetDelegateCalls;
persistent ghost mathint facetCreates;
persistent ghost mapping(address => bool) facetCalledTarget;
persistent ghost mapping(address => bool) sceneCalledTarget;
persistent ghost mathint sceneDelegateCalls;
persistent ghost mathint sceneCreates;

// Targets called while no rate limit had been decreased yet
persistent ghost mapping(address => bool) calledBeforeDecrease;

// Calls carrying ETH, anywhere in the scene
persistent ghost mathint sceneValueCalls;

// --- Hooks ---

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    sceneCalledTarget[addr] = true;
    if (value > 0) {
        sceneValueCalls = sceneValueCalls + 1;
    }
    if (rateLimitDecreases == 0) {
        calledBeforeDecrease[addr] = true;
    }
    if (executingContract == currentContract) {
        facetCalls              = facetCalls + 1;
        facetCalledTarget[addr] = true;
    }
}

hook CALLCODE(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    sceneCalledTarget[addr] = true;
    if (executingContract == currentContract) {
        facetCalls              = facetCalls + 1;
        facetCalledTarget[addr] = true;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    sceneDelegateCalls = sceneDelegateCalls + 1;
    if (executingContract == currentContract) {
        facetDelegateCalls = facetDelegateCalls + 1;
    }
}

hook CREATE1(uint value, uint offset, uint length) address v {
    sceneCreates = sceneCreates + 1;
    if (executingContract == currentContract) {
        facetCreates = facetCreates + 1;
    }
}

hook CREATE2(uint value, uint offset, uint length, bytes32 salt) address v {
    sceneCreates = sceneCreates + 1;
    if (executingContract == currentContract) {
        facetCreates = facetCreates + 1;
    }
}

// --- Summaries ---

function cvlTriggerRateLimitDecrease(bytes32 key, uint256 amount) returns uint256 {
    rateLimitDecreases  = rateLimitDecreases + 1;
    lastDecreasedKey    = key;
    lastDecreasedAmount = amount;
    decreasesOfKey[key] = decreasesOfKey[key] + 1;
    decreasedByKey[key] = decreasedByKey[key] + amount;
    uint256 newLimit;
    return newLimit;
}

function cvlTriggerRateLimitIncrease(bytes32 key, uint256 amount) returns uint256 {
    rateLimitIncreases = rateLimitIncreases + 1;
    uint256 newLimit;
    return newLimit;
}

function cvlGetRateLimitData(bytes32 key) returns IRateLimits.RateLimitData {
    rateLimitReads = rateLimitReads + 1;
    IRateLimits.RateLimitData data;
    require data.maxAmount == rateLimitMaxAmount(key);
    return data;
}

function cvlGetCurrentRateLimit(bytes32 key) returns uint256 {
    rateLimitReads = rateLimitReads + 1;
    uint256 limit;
    return limit;
}

// --- Definitions ---

// ReentrancyGuardUpgradeable states
definition NOT_ENTERED() returns uint256 = 1;
definition ENTERED()     returns uint256 = 2;

// openzeppelin.storage.ReentrancyGuard
definition status() returns uint256 = currentContract.ext_openzeppelin_storage_ReentrancyGuard._status;

// sky.pau.storage.SharedController
definition accessControlsSlot() returns address = currentContract.ext_sky_pau_storage_SharedController.accessControls;
definition proxySlot()          returns address = currentContract.ext_sky_pau_storage_SharedController.proxy;
definition rateLimitsSlot()     returns address = currentContract.ext_sky_pau_storage_SharedController.rateLimits;

definition isAdmin(address account)     returns bool = hasRoleGhost(DEFAULT_ADMIN_ROLE(), account);
definition isAllocator(address account) returns bool = hasRoleGhost(ALLOCATOR_ROLE(), account);

// --- Access control ---

// Every non-view function is gated by DEFAULT_ADMIN_ROLE or ALLOCATOR_ROLE
rule roleGated(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require !isAdmin(e.msg.sender) && !isAllocator(e.msg.sender);

    f@withrevert(e, args);

    assert lastReverted;
}

// Admin functions only configure the facet: they never touch the rate limits nor move value,
// and more generally make no external call other than reads (static calls)
rule adminIsConfigurationOnly(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require isAdmin(e.msg.sender) && !isAllocator(e.msg.sender);

    require rateLimitDecreases == 0 && rateLimitIncreases == 0 && rateLimitReads == 0;
    require facetCalls == 0 && facetDelegateCalls == 0 && facetCreates == 0;

    // Allocator functions revert for this sender: the call is made with @withrevert so that the
    // rule stays non-vacuous for them
    f@withrevert(e, args);

    assert !lastReverted => rateLimitDecreases == 0;
    assert !lastReverted => rateLimitIncreases == 0;
    assert !lastReverted => rateLimitReads     == 0;
    assert !lastReverted => facetCalls         == 0;
    assert !lastReverted => facetDelegateCalls == 0;
    assert !lastReverted => facetCreates       == 0;
}

// --- Rate limits ---

// No allocator function can succeed without a configured rate limit for its action. With every
// maxAmount at zero, `_rateLimitExists` gates revert on their own, and the only way left to
// succeed is to call triggerRateLimitDecrease, which RateLimits rejects for a zero maxAmount.
rule allocatorRequiresRateLimit(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require isAllocator(e.msg.sender) && !isAdmin(e.msg.sender);

    require forall bytes32 key. rateLimitMaxAmount(key) == 0;
    require rateLimitDecreases == 0;

    // Admin functions revert for this sender: the call is made with @withrevert so that the
    // rule stays non-vacuous for them
    f@withrevert(e, args);

    assert !lastReverted => rateLimitDecreases > 0;
}

// --- External interactions ---

// A facet only acts on the outside world through the proxy and the rate limits: every non-static
// external call it issues targets one of them, and it never delegatecalls nor deploys. The body is
// a CVL function so that a facet spec which has to make one direct call outside the proxy can
// re-run the same check over every other function and cover that one with a rule of its own.
function checkExternalCallsOnlyToProxyAndRateLimits(method f) {
    env e;
    calldataarg args;

    require forall address a. !facetCalledTarget[a];
    require facetDelegateCalls == 0 && facetCreates == 0;

    address proxy      = proxySlot();
    address rateLimits = rateLimitsSlot();

    f@withrevert(e, args);

    assert !lastReverted => (forall address a. facetCalledTarget[a] => a == proxy || a == rateLimits);
    assert !lastReverted => facetDelegateCalls == 0;
    assert !lastReverted => facetCreates       == 0;
}

rule externalCallsOnlyToProxyAndRateLimits(method f) filtered { f -> !f.isView } {
    checkExternalCallsOnlyToProxyAndRateLimits(f);
}

// --- Reentrancy ---

// Every non-view function is nonReentrant
rule reentrancyGuarded(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require status() == ENTERED();

    f@withrevert(e, args);

    assert lastReverted;
}

// --- Storage isolation ---

// The shared addresses are never written and the reentrancy guard is always released on exit
rule sharedStorageUntouched(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    address accessControlsBefore = accessControlsSlot();
    address proxyBefore          = proxySlot();
    address rateLimitsBefore     = rateLimitsSlot();

    f(e, args);

    assert accessControlsSlot() == accessControlsBefore;
    assert proxySlot()          == proxyBefore;
    assert rateLimitsSlot()     == rateLimitsBefore;
    assert status()             == NOT_ENTERED();
}
