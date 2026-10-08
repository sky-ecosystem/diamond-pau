// FacetBase.spec
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
    // The one exception is doDelegateCall, the proxy's most powerful entry point (the target runs
    // with the proxy's storage and funds): it is recorded so that noProxyDelegateCalls can prove
    // no facet ever reaches it.
    function _.doDelegateCall(address target, bytes data) external => cvlDoDelegateCall() expect bytes;
}

// --- Ghosts ---

persistent ghost hasRoleGhost(bytes32, address) returns bool;

// Configured maxAmount per rate limit key
persistent ghost rateLimitMaxAmount(bytes32) returns uint256;

persistent ghost mathint rateLimitDecreases;
persistent ghost mathint rateLimitIncreases;
persistent ghost bytes32 lastDecreasedKey;
persistent ghost uint256 lastDecreasedAmount;
persistent ghost bytes32 lastIncreasedKey;
persistent ghost uint256 lastIncreasedAmount;
persistent ghost mapping(bytes32 => mathint) decreasesOfKey;   // number of decreases per key
persistent ghost mapping(bytes32 => mathint) decreasedByKey;   // total amount decreased per key

// Every non-static external interaction, recorded at the opcode level so that nothing escapes
// the summaries above (any proxy entry point, other contracts, delegatecalls, deployments).
// The `facet*` ghosts only count what the facet itself issues (executingContract is the facet);
// the `scene*` ghosts count every contract in the scene, e.g. what the proxy forwards.
persistent ghost mathint facetCalls;
persistent ghost mathint facetDelegateCalls;
persistent ghost mathint facetCallcodes;
persistent ghost mathint proxyDelegateCalls;

// Mirror of the shared reentrancy guard slot (ERC-7201 openzeppelin.storage.ReentrancyGuard), and
// a flag set when the facet issues a CALL while that slot does not hold the lock
persistent ghost uint256 guardStatus;
persistent ghost bool    calledWhileUnlocked;
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
        if (guardStatus != ENTERED()) {
            calledWhileUnlocked = true;
        }
    }
}

hook Sload uint256 v currentContract.ext_openzeppelin_storage_ReentrancyGuard._status {
    require guardStatus == v;
}

hook Sstore currentContract.ext_openzeppelin_storage_ReentrancyGuard._status uint256 newValue {
    guardStatus = newValue;
}

// CALLCODE is deprecated and never emitted by Solidity; it is counted on its own so that
// noForbiddenCalls can prove it never happens, and it is not part of facetCalls
hook CALLCODE(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    sceneCalledTarget[addr] = true;
    if (executingContract == currentContract) {
        facetCallcodes = facetCallcodes + 1;
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

function cvlDoDelegateCall() returns bytes {
    proxyDelegateCalls = proxyDelegateCalls + 1;
    bytes result;
    return result;
}

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
    rateLimitIncreases  = rateLimitIncreases + 1;
    lastIncreasedKey    = key;
    lastIncreasedAmount = amount;
    uint256 newLimit;
    return newLimit;
}

function cvlGetRateLimitData(bytes32 key) returns IRateLimits.RateLimitData {
    IRateLimits.RateLimitData data;
    require data.maxAmount == rateLimitMaxAmount(key);
    return data;
}

function cvlGetCurrentRateLimit(bytes32 key) returns uint256 {
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

// Admin functions only configure the facet: they make no external call other than reads (static
// calls), so they neither touch the rate limits nor move value (see rateLimitCallsAreFacetCalls)
rule adminIsConfigurationOnly(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require isAdmin(e.msg.sender) && !isAllocator(e.msg.sender);

    require facetCalls == 0;

    // Allocator functions revert for this sender: the call is made with @withrevert so that the
    // rule stays non-vacuous for them
    f@withrevert(e, args);

    assert !lastReverted => facetCalls == 0;
}

// --- Rate limits ---

// Every rate limit decrease or increase is a CALL issued by the facet: a summarised call still
// executes the CALL opcode, so the facet call counter sees it. This pins down a property of the
// model that other rules rely on (`facetCalls == 0` implies no rate limit was touched), so that a
// change in how the Prover applies hooks to summarised calls shows up here.
rule rateLimitCallsAreFacetCalls(method f) {
    env e;
    calldataarg args;

    require facetCalls == 0 && rateLimitDecreases == 0 && rateLimitIncreases == 0;

    f(e, args);

    assert rateLimitDecreases > 0 || rateLimitIncreases > 0 => facetCalls > 0;
}


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

// A facet never delegatecalls, callcodes nor deploys a contract, in any function and for any
// caller, so a CALL is its only way to act on the outside world. A facet that legitimately needs
// any of them simply does not use this rule.
rule noForbiddenCalls(method f) {
    env e;
    calldataarg args;

    require facetDelegateCalls == 0 && facetCallcodes == 0 && facetCreates == 0;

    f(e, args);

    assert facetDelegateCalls == 0;
    assert facetCallcodes     == 0;
    assert facetCreates       == 0;
}

// No facet ever asks the proxy to delegatecall, in any function and for any caller. A facet that
// legitimately needs ALMProxy.doDelegateCall simply does not use this rule.
rule noProxyDelegateCalls(method f) {
    env e;
    calldataarg args;

    require proxyDelegateCalls == 0;

    f(e, args);

    assert proxyDelegateCalls == 0;
}


// A facet only acts on the outside world through the proxy and the rate limits: every non-static
// external call it issues targets one of them. The body is
// a CVL function so that a facet spec which has to make one direct call outside the proxy can
// re-run the same check over every other function and cover that one with a rule of its own.
function checkExternalCallsOnlyToProxyAndRateLimits(method f) {
    env e;
    calldataarg args;

    require forall address a. !facetCalledTarget[a];

    address proxy      = proxySlot();
    address rateLimits = rateLimitsSlot();

    f@withrevert(e, args);

    assert !lastReverted => (forall address a. facetCalledTarget[a] => a == proxy || a == rateLimits);
}

rule externalCallsOnlyToProxyAndRateLimits(method f) filtered { f -> !f.isView } {
    checkExternalCallsOnlyToProxyAndRateLimits(f);
}

// --- Reentrancy ---

// Every non-view function holds the shared reentrancy lock (ERC-7201 openzeppelin.storage.
// ReentrancyGuard): it reverts when the slot is already locked, every external call it issues
// happens while the slot holds the lock, and the lock is released on exit. So no facet can be
// re-entered through another facet of the same Controller while it calls out.
rule reentrancyGuarded(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    uint256 statusBefore = status();

    require guardStatus == statusBefore;
    require !calledWhileUnlocked;

    f@withrevert(e, args);

    assert statusBefore == ENTERED() => lastReverted;
    assert !lastReverted => !calledWhileUnlocked;
    assert !lastReverted => status() == NOT_ENTERED();
}

// --- Storage isolation ---

// The shared addresses are never written
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
}
