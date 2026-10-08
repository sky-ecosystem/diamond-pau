// ALMProxyFreezable.spec

import "ALMProxyBase.spec";

// --- Methods block ---

methods {
    function ALLOCATOR_ROLE() external returns (bytes32) envfree;
    function FREEZER_ROLE()   external returns (bytes32) envfree;
}

// doCall and doCallWithValue are gated by ALLOCATOR_ROLE
override definition callerRole() returns bytes32 = ALLOCATOR_ROLE();

// --- Shared rules ---

use rule constants;
use rule hasRole_correctness;
use rule getRoleAdmin_correctness;
use rule supportsInterface_correctness;
use rule grantRole;
use rule grantRole_revert;
use rule revokeRole;
use rule revokeRole_revert;
use rule renounceRole;
use rule renounceRole_revert;
use rule doCall;
use rule doCall_revert;
use rule doCallWithValue;
use rule doCallWithValue_revert;
use rule receiveETH;

// --- Storage Affected Rule ---

// Roles only change through the AccessControl functions and removeAllocator, and role admins never
// change
rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    bytes32 anyRole;
    address anyAccount;

    bool    hasRoleBefore   = roleHas(anyRole, anyAccount);
    bytes32 roleAdminBefore = roleAdmin(anyRole);

    f(e, args);

    assert roleHas(anyRole, anyAccount) != hasRoleBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector ||
        f.selector == sig:removeAllocator(address).selector;
    assert roleAdmin(anyRole) == roleAdminBefore;
}

// --- Freezer functions: removeAllocator ---

// The allocator loses ALLOCATOR_ROLE and nothing else changes
rule removeAllocator(address allocator) {
    env e;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != ALLOCATOR_ROLE() || otherAccount != allocator;

    bool otherHasRoleBefore = roleHas(otherRole, otherAccount);

    removeAllocator(e, allocator);

    assert !roleHas(ALLOCATOR_ROLE(), allocator);
    assert roleHas(otherRole, otherAccount) == otherHasRoleBefore;
}

rule removeAllocator_revert(address allocator) {
    env e;

    bool senderIsFreezer = roleHas(FREEZER_ROLE(), e.msg.sender);
    bool isLiveAllocator = roleHas(ALLOCATOR_ROLE(), allocator);

    removeAllocator@withrevert(e, allocator);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsFreezer;
    bool revert3 = !isLiveAllocator;

    assert lastReverted <=> revert1 || revert2 || revert3;
}
