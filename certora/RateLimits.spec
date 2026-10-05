// RateLimits.spec

// --- Methods block ---

methods {
    // AccessControl
    function DEFAULT_ADMIN_ROLE()      external returns (bytes32) envfree;
    function hasRole(bytes32, address) external returns (bool)    envfree;
    function getRoleAdmin(bytes32)     external returns (bytes32) envfree;
    function supportsInterface(bytes4) external returns (bool)    envfree;

    // RateLimits
    function CONTROLLER()              external returns (bytes32)                   envfree;
    function getRateLimitData(bytes32) external returns (IRateLimits.RateLimitData) envfree;
}

// --- Definitions ---

// ERC-165 interface ids: IAccessControl, IERC165
definition IACCESS_CONTROL_ID() returns bytes4 = to_bytes4(0x7965db0b);
definition IERC165_ID()         returns bytes4 = to_bytes4(0x01ffc9a7);

// --- Storage accessors (direct storage access) ---

// AccessControl._roles[role].hasRole[account] / .adminRole
definition roleHas(bytes32 role, address account) returns bool    = currentContract._roles[role].hasRole[account];
definition roleAdmin(bytes32 role)                returns bytes32 = currentContract._roles[role].adminRole;

// RateLimits._data[key]
definition maxAmountOf(bytes32 key)   returns uint256 = currentContract._data[key].maxAmount;
definition slopeOf(bytes32 key)       returns uint256 = currentContract._data[key].slope;
definition lastAmountOf(bytes32 key)  returns uint256 = currentContract._data[key].lastAmount;
definition lastUpdatedOf(bytes32 key) returns uint256 = currentContract._data[key].lastUpdated;

// --- Rate limit arithmetic ---

// The amount regenerated since the last update, before the cap: slope * elapsed + lastAmount
definition regenerated(bytes32 key, uint256 timestamp) returns mathint =
    slopeOf(key) * (timestamp - lastUpdatedOf(key)) + lastAmountOf(key);

// Mirrors getCurrentRateLimit for the non-overflowing case
definition currentLimit(bytes32 key, uint256 timestamp) returns mathint =
    maxAmountOf(key) == max_uint256 ? max_uint256 :
    (regenerated(key, timestamp) < maxAmountOf(key) ? regenerated(key, timestamp) : maxAmountOf(key));

// The checked arithmetic of getCurrentRateLimit reverts: the last update is in the future, or the
// multiplication or the addition overflows. Only reached when the key is not unlimited.
definition currentLimitReverts(bytes32 key, uint256 timestamp) returns bool =
    maxAmountOf(key) != max_uint256 && (
        lastUpdatedOf(key) > timestamp ||
        slopeOf(key) * (timestamp - lastUpdatedOf(key)) > max_uint256 ||
        regenerated(key, timestamp) > max_uint256
    );

// --- Storage Affected Rule ---

rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    bytes32 anyRole;
    address anyAccount;
    bytes32 anyKey;

    bool    hasRoleBefore     = roleHas(anyRole, anyAccount);
    bytes32 roleAdminBefore   = roleAdmin(anyRole);
    uint256 maxAmountBefore   = maxAmountOf(anyKey);
    uint256 slopeBefore       = slopeOf(anyKey);
    uint256 lastAmountBefore  = lastAmountOf(anyKey);
    uint256 lastUpdatedBefore = lastUpdatedOf(anyKey);

    f(e, args);

    // Role admins are never changed
    assert roleAdmin(anyRole) == roleAdminBefore;

    assert roleHas(anyRole, anyAccount) != hasRoleBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;

    // The configuration of a limit is only written by the admin setters
    assert maxAmountOf(anyKey) != maxAmountBefore =>
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256, uint256, uint256).selector ||
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256).selector ||
        f.selector == sig:setUnlimitedRateLimitData(bytes32).selector;
    assert slopeOf(anyKey) != slopeBefore =>
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256, uint256, uint256).selector ||
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256).selector ||
        f.selector == sig:setUnlimitedRateLimitData(bytes32).selector;

    // The state of a limit is also written by the controller triggers
    assert lastAmountOf(anyKey) != lastAmountBefore =>
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256, uint256, uint256).selector ||
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256).selector ||
        f.selector == sig:setUnlimitedRateLimitData(bytes32).selector ||
        f.selector == sig:triggerRateLimitDecrease(bytes32, uint256).selector ||
        f.selector == sig:triggerRateLimitIncrease(bytes32, uint256).selector;
    assert lastUpdatedOf(anyKey) != lastUpdatedBefore =>
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256, uint256, uint256).selector ||
        f.selector == sig:setRateLimitData(bytes32, uint256, uint256).selector ||
        f.selector == sig:setUnlimitedRateLimitData(bytes32).selector ||
        f.selector == sig:triggerRateLimitDecrease(bytes32, uint256).selector ||
        f.selector == sig:triggerRateLimitIncrease(bytes32, uint256).selector;
}

// --- View function correctness ---

rule constants() {
    assert DEFAULT_ADMIN_ROLE() == to_bytes32(0);
}

rule hasRole_correctness(bytes32 role, address account) {
    assert hasRole(role, account) == roleHas(role, account);
}

rule getRoleAdmin_correctness(bytes32 role) {
    assert getRoleAdmin(role) == roleAdmin(role);
}

rule supportsInterface_correctness(bytes4 interfaceId) {
    assert supportsInterface(interfaceId) <=> interfaceId == IACCESS_CONTROL_ID() || interfaceId == IERC165_ID();
}

rule getRateLimitData_correctness(bytes32 key) {
    IRateLimits.RateLimitData data = getRateLimitData(key);

    assert data.maxAmount   == maxAmountOf(key);
    assert data.slope       == slopeOf(key);
    assert data.lastAmount  == lastAmountOf(key);
    assert data.lastUpdated == lastUpdatedOf(key);
}

rule getCurrentRateLimit_correctness(bytes32 key) {
    env e;

    assert getCurrentRateLimit(e, key) == currentLimit(key, e.block.timestamp);
}

rule getCurrentRateLimit_revert(bytes32 key) {
    env e;

    bool reverts = currentLimitReverts(key, e.block.timestamp);

    getCurrentRateLimit@withrevert(e, key);

    bool revert1 = e.msg.value > 0;
    bool revert2 = reverts;

    assert lastReverted <=> revert1 || revert2;
}

// --- Access control functions: grantRole ---

rule grantRole(bytes32 role, address account) {
    env e;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;

    bool otherHasRoleBefore = roleHas(otherRole, otherAccount);

    grantRole(e, role, account);

    assert roleHas(role, account);
    assert roleHas(otherRole, otherAccount) == otherHasRoleBefore;
}

rule grantRole_revert(bytes32 role, address account) {
    env e;

    bool senderIsRoleAdmin = roleHas(roleAdmin(role), e.msg.sender);

    grantRole@withrevert(e, role, account);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsRoleAdmin;

    assert lastReverted <=> revert1 || revert2;
}

// --- Access control functions: revokeRole ---

rule revokeRole(bytes32 role, address account) {
    env e;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;

    bool otherHasRoleBefore = roleHas(otherRole, otherAccount);

    revokeRole(e, role, account);

    assert !roleHas(role, account);
    assert roleHas(otherRole, otherAccount) == otherHasRoleBefore;
}

rule revokeRole_revert(bytes32 role, address account) {
    env e;

    bool senderIsRoleAdmin = roleHas(roleAdmin(role), e.msg.sender);

    revokeRole@withrevert(e, role, account);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsRoleAdmin;

    assert lastReverted <=> revert1 || revert2;
}

// --- Access control functions: renounceRole ---

rule renounceRole(bytes32 role, address callerConfirmation) {
    env e;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != e.msg.sender;

    bool otherHasRoleBefore = roleHas(otherRole, otherAccount);

    renounceRole(e, role, callerConfirmation);

    assert !roleHas(role, e.msg.sender);
    assert roleHas(otherRole, otherAccount) == otherHasRoleBefore;
}

rule renounceRole_revert(bytes32 role, address callerConfirmation) {
    env e;

    renounceRole@withrevert(e, role, callerConfirmation);

    bool revert1 = e.msg.value > 0;
    bool revert2 = callerConfirmation != e.msg.sender;

    assert lastReverted <=> revert1 || revert2;
}

// --- Admin functions: setRateLimitData (full) ---

rule setRateLimitData(bytes32 key, uint256 maxAmount, uint256 slope, uint256 lastAmount, uint256 lastUpdated) {
    env e;

    bytes32 otherKey;
    require otherKey != key;

    uint256 otherMaxAmountBefore   = maxAmountOf(otherKey);
    uint256 otherSlopeBefore       = slopeOf(otherKey);
    uint256 otherLastAmountBefore  = lastAmountOf(otherKey);
    uint256 otherLastUpdatedBefore = lastUpdatedOf(otherKey);

    setRateLimitData(e, key, maxAmount, slope, lastAmount, lastUpdated);

    assert maxAmountOf(key)   == maxAmount;
    assert slopeOf(key)       == slope;
    assert lastAmountOf(key)  == lastAmount;
    assert lastUpdatedOf(key) == lastUpdated;

    assert maxAmountOf(otherKey)   == otherMaxAmountBefore;
    assert slopeOf(otherKey)       == otherSlopeBefore;
    assert lastAmountOf(otherKey)  == otherLastAmountBefore;
    assert lastUpdatedOf(otherKey) == otherLastUpdatedBefore;
}

rule setRateLimitData_revert(bytes32 key, uint256 maxAmount, uint256 slope, uint256 lastAmount, uint256 lastUpdated) {
    env e;

    bool senderIsAdmin = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    setRateLimitData@withrevert(e, key, maxAmount, slope, lastAmount, lastUpdated);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsAdmin;
    bool revert3 = lastAmount > maxAmount;
    bool revert4 = lastUpdated > e.block.timestamp;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4;
}

// --- Admin functions: setRateLimitData (full limit, updated now) ---

rule setRateLimitDataShort(bytes32 key, uint256 maxAmount, uint256 slope) {
    env e;

    bytes32 otherKey;
    require otherKey != key;

    uint256 otherMaxAmountBefore   = maxAmountOf(otherKey);
    uint256 otherSlopeBefore       = slopeOf(otherKey);
    uint256 otherLastAmountBefore  = lastAmountOf(otherKey);
    uint256 otherLastUpdatedBefore = lastUpdatedOf(otherKey);

    setRateLimitData(e, key, maxAmount, slope);

    assert maxAmountOf(key)   == maxAmount;
    assert slopeOf(key)       == slope;
    assert lastAmountOf(key)  == maxAmount;
    assert lastUpdatedOf(key) == e.block.timestamp;

    assert maxAmountOf(otherKey)   == otherMaxAmountBefore;
    assert slopeOf(otherKey)       == otherSlopeBefore;
    assert lastAmountOf(otherKey)  == otherLastAmountBefore;
    assert lastUpdatedOf(otherKey) == otherLastUpdatedBefore;
}

rule setRateLimitDataShort_revert(bytes32 key, uint256 maxAmount, uint256 slope) {
    env e;

    bool senderIsAdmin = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    setRateLimitData@withrevert(e, key, maxAmount, slope);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsAdmin;

    assert lastReverted <=> revert1 || revert2;
}

// --- Admin functions: setUnlimitedRateLimitData ---

rule setUnlimitedRateLimitData(bytes32 key) {
    env e;

    bytes32 otherKey;
    require otherKey != key;

    uint256 otherMaxAmountBefore   = maxAmountOf(otherKey);
    uint256 otherSlopeBefore       = slopeOf(otherKey);
    uint256 otherLastAmountBefore  = lastAmountOf(otherKey);
    uint256 otherLastUpdatedBefore = lastUpdatedOf(otherKey);

    setUnlimitedRateLimitData(e, key);

    assert maxAmountOf(key)   == max_uint256;
    assert slopeOf(key)       == 0;
    assert lastAmountOf(key)  == max_uint256;
    assert lastUpdatedOf(key) == e.block.timestamp;

    assert maxAmountOf(otherKey)   == otherMaxAmountBefore;
    assert slopeOf(otherKey)       == otherSlopeBefore;
    assert lastAmountOf(otherKey)  == otherLastAmountBefore;
    assert lastUpdatedOf(otherKey) == otherLastUpdatedBefore;
}

rule setUnlimitedRateLimitData_revert(bytes32 key) {
    env e;

    bool senderIsAdmin = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    setUnlimitedRateLimitData@withrevert(e, key);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsAdmin;

    assert lastReverted <=> revert1 || revert2;
}

// --- Controller functions: triggerRateLimitDecrease ---

rule triggerRateLimitDecrease(bytes32 key, uint256 amountToDecrease) {
    env e;

    bytes32 otherKey;
    require otherKey != key;

    bool    unlimited         = maxAmountOf(key) == max_uint256;
    mathint current           = currentLimit(key, e.block.timestamp);
    uint256 maxAmountBefore   = maxAmountOf(key);
    uint256 slopeBefore       = slopeOf(key);
    uint256 lastAmountBefore  = lastAmountOf(key);
    uint256 lastUpdatedBefore = lastUpdatedOf(key);

    uint256 otherMaxAmountBefore   = maxAmountOf(otherKey);
    uint256 otherSlopeBefore       = slopeOf(otherKey);
    uint256 otherLastAmountBefore  = lastAmountOf(otherKey);
    uint256 otherLastUpdatedBefore = lastUpdatedOf(otherKey);

    uint256 newLimit = triggerRateLimitDecrease(e, key, amountToDecrease);

    // The configuration of the limit is untouched
    assert maxAmountOf(key) == maxAmountBefore;
    assert slopeOf(key)     == slopeBefore;
    // Unlimited: nothing is consumed and nothing is written
    assert unlimited => newLimit == max_uint256;
    assert unlimited => lastAmountOf(key)  == lastAmountBefore;
    assert unlimited => lastUpdatedOf(key) == lastUpdatedBefore;
    // Limited: the current limit is reduced by the amount and checkpointed now
    assert !unlimited => newLimit == current - amountToDecrease;
    assert !unlimited => lastAmountOf(key)  == newLimit;
    assert !unlimited => lastUpdatedOf(key) == e.block.timestamp;
    // Other keys are untouched
    assert maxAmountOf(otherKey)   == otherMaxAmountBefore;
    assert slopeOf(otherKey)       == otherSlopeBefore;
    assert lastAmountOf(otherKey)  == otherLastAmountBefore;
    assert lastUpdatedOf(otherKey) == otherLastUpdatedBefore;
}

rule triggerRateLimitDecrease_revert(bytes32 key, uint256 amountToDecrease) {
    env e;

    bool    senderIsController = roleHas(CONTROLLER(), e.msg.sender);
    uint256 maxAmount          = maxAmountOf(key);
    bool    limitReverts       = currentLimitReverts(key, e.block.timestamp);
    mathint current            = currentLimit(key, e.block.timestamp);

    triggerRateLimitDecrease@withrevert(e, key, amountToDecrease);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsController;
    bool revert3 = maxAmount == 0;
    bool revert4 = limitReverts;
    bool revert5 = maxAmount != max_uint256 && amountToDecrease > current;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}

// --- Controller functions: triggerRateLimitIncrease ---

rule triggerRateLimitIncrease(bytes32 key, uint256 amountToIncrease) {
    env e;

    bytes32 otherKey;
    require otherKey != key;

    bool    unlimited         = maxAmountOf(key) == max_uint256;
    mathint current           = currentLimit(key, e.block.timestamp);
    uint256 maxAmountBefore   = maxAmountOf(key);
    uint256 slopeBefore       = slopeOf(key);
    uint256 lastAmountBefore  = lastAmountOf(key);
    uint256 lastUpdatedBefore = lastUpdatedOf(key);

    uint256 otherMaxAmountBefore   = maxAmountOf(otherKey);
    uint256 otherSlopeBefore       = slopeOf(otherKey);
    uint256 otherLastAmountBefore  = lastAmountOf(otherKey);
    uint256 otherLastUpdatedBefore = lastUpdatedOf(otherKey);

    uint256 newLimit = triggerRateLimitIncrease(e, key, amountToIncrease);

    mathint increased = current + amountToIncrease;

    // The configuration of the limit is untouched
    assert maxAmountOf(key) == maxAmountBefore;
    assert slopeOf(key)     == slopeBefore;
    // Unlimited: nothing is written
    assert unlimited => newLimit == max_uint256;
    assert unlimited => lastAmountOf(key)  == lastAmountBefore;
    assert unlimited => lastUpdatedOf(key) == lastUpdatedBefore;
    // Limited: the current limit is increased by the amount, capped at the maximum, and
    // checkpointed now
    assert !unlimited => newLimit == (increased < maxAmountBefore ? increased : maxAmountBefore);
    assert !unlimited => lastAmountOf(key)  == newLimit;
    assert !unlimited => lastUpdatedOf(key) == e.block.timestamp;
    // Other keys are untouched
    assert maxAmountOf(otherKey)   == otherMaxAmountBefore;
    assert slopeOf(otherKey)       == otherSlopeBefore;
    assert lastAmountOf(otherKey)  == otherLastAmountBefore;
    assert lastUpdatedOf(otherKey) == otherLastUpdatedBefore;
}

rule triggerRateLimitIncrease_revert(bytes32 key, uint256 amountToIncrease) {
    env e;

    bool    senderIsController = roleHas(CONTROLLER(), e.msg.sender);
    uint256 maxAmount          = maxAmountOf(key);
    bool    limitReverts       = currentLimitReverts(key, e.block.timestamp);
    mathint current            = currentLimit(key, e.block.timestamp);

    triggerRateLimitIncrease@withrevert(e, key, amountToIncrease);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsController;
    bool revert3 = maxAmount == 0;
    bool revert4 = limitReverts;
    bool revert5 = maxAmount != max_uint256 && current + amountToIncrease > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}
