// ALMProxyFreezable.spec

import "ALMProxyBase.spec";

// --- Methods block ---

methods {
    function ALLOCATOR_ROLE() external returns (bytes32) envfree;
    function FREEZER_ROLE()   external returns (bytes32) envfree;
}

// doCall and doCallWithValue are gated by ALLOCATOR_ROLE
override definition callerRole() returns bytes32 = ALLOCATOR_ROLE();

// --- Shared rules: AccessControlEnumerableBase.spec ---

// removeAllocator also removes from the ALLOCATOR_ROLE set (swap and pop), so it gets the same
// preserved blocks as revokeRole. These add to the imported preserved blocks.
use invariant roleMembershipConsistency {
    preserved removeAllocator(address allocator) with (env e) {
        requireLastMemberIsMember(role);
    }
}

use invariant roleMemberIsAddress {
    preserved removeAllocator(address allocator) with (env e) {
        requireLastMemberIsAddress(role);
    }
}

use invariant roleMemberAtIsMember {
    preserved removeAllocator(address allocator) with (env e) {
        requireLastMemberIsMember(role);
    }
}

use invariant roleMemberPosIndexed {
    preserved removeAllocator(address allocator) with (env e) {
        requireLastMemberIsMember(role);
        requireRemovedIsIndexed(role, allocator);
    }
}

use rule DEFAULT_ADMIN_ROLE_correctness;
use rule hasRole_correctness;
use rule getRoleAdmin_correctness;
use rule getRoleMemberCount_correctness;
use rule getRoleMember_correctness;
use rule getRoleMember_revert;
use rule supportsInterface_correctness;
use rule grantRole;
use rule grantRole_revert;
use rule revokeRole;
use rule revokeRole_notMember;
use rule revokeRole_revert;
use rule renounceRole;
use rule renounceRole_notMember;
use rule renounceRole_revert;

// --- Shared rules: ALMProxyBase.spec ---

use rule doCall;
use rule doCall_revert;
use rule doCallWithValue;
use rule doCallWithValue_revert;
use rule receiveETH;

// --- Storage Affected Rule ---

// Roles and role sets only change through the AccessControl functions and removeAllocator, and
// role admins never change
rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    bytes32 anyRole;
    address anyAccount;
    bytes32 anyValue;
    uint256 anyMemberIdx;

    // Element reads are pinned inside the array
    require anyMemberIdx < roleMemberCount(anyRole);

    bool    hasRoleBefore         = roleHas(anyRole, anyAccount);
    bytes32 roleAdminBefore       = roleAdmin(anyRole);
    uint256 roleMemberCountBefore = roleMemberCount(anyRole);
    bytes32 roleMemberAtBefore    = roleMemberAt(anyRole, anyMemberIdx);
    uint256 roleMemberPosBefore   = roleMemberPosRaw(anyRole, anyValue);

    f(e, args);

    uint256 roleMemberCountAfter = roleMemberCount(anyRole);

    // Element reads after the call are only meaningful while still in range
    bytes32 roleMemberAtAfter = anyMemberIdx < roleMemberCountAfter ? roleMemberAt(anyRole, anyMemberIdx) : roleMemberAtBefore;

    assert roleAdmin(anyRole) == roleAdminBefore;

    assert roleHas(anyRole, anyAccount) != hasRoleBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector ||
        f.selector == sig:removeAllocator(address).selector;
    assert roleMemberCountAfter != roleMemberCountBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector ||
        f.selector == sig:removeAllocator(address).selector;
    assert roleMemberAtAfter != roleMemberAtBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector ||
        f.selector == sig:removeAllocator(address).selector;
    assert roleMemberPosRaw(anyRole, anyValue) != roleMemberPosBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector ||
        f.selector == sig:removeAllocator(address).selector;
}

// --- Freezer functions: removeAllocator ---

// The allocator holds ALLOCATOR_ROLE (removeAllocator reverts otherwise) and is a member of the
// set: it loses the role and is removed from the set by swap and pop, and nothing else changes
rule removeAllocator(address allocator) {
    env e;

    bytes32 role    = ALLOCATOR_ROLE();
    address account = allocator;

    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, account);

    require roleHas(role, account);

    uint256 idx;
    require idx + 1 == roleMemberPosBefore;
    uint256 lastIdx;
    require lastIdx + 1 == roleMemberCountBefore;
    bytes32 lastMember = roleMemberAt(role, lastIdx);
    // The last member is either the removed one or another consistent member
    requireInvariant roleMemberAtIsMember(role, lastIdx);

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;
    require otherRole != role || to_bytes32(otherAccount) != lastMember;
    uint256 otherIdx;
    require otherIdx != idx;
    require lastIdx == 0 || otherIdx < lastIdx;

    bool    otherHasRoleBefore     = roleHas(otherRole, otherAccount);
    uint256 otherMemberCountBefore = roleMemberCount(otherRole);
    uint256 otherMemberPosBefore   = roleMemberPos(otherRole, otherAccount);
    bytes32 otherMemberAtBefore    = roleMemberAt(role, otherIdx);

    removeAllocator(e, allocator);

    // The allocator no longer holds ALLOCATOR_ROLE and is removed from the set
    assert !roleHas(role, account);
    assert roleMemberPos(role, account) == 0;
    assert roleMemberCount(role)        == roleMemberCountBefore - 1;
    // The last member takes the removed slot (unless it was the removed one)
    assert idx != lastIdx => roleMemberAt(role, idx)            == lastMember;
    assert idx != lastIdx => roleMemberPosRaw(role, lastMember) == roleMemberPosBefore;
    // Other (role, account) pairs are untouched
    assert roleHas(otherRole, otherAccount)       == otherHasRoleBefore;
    assert roleMemberPos(otherRole, otherAccount) == otherMemberPosBefore;
    assert otherRole != role => roleMemberCount(otherRole) == otherMemberCountBefore;
    assert otherIdx < lastIdx => roleMemberAt(role, otherIdx) == otherMemberAtBefore;
}

rule removeAllocator_revert(address allocator) {
    env e;

    bool    senderIsFreezer       = roleHas(FREEZER_ROLE(), e.msg.sender);
    bool    isLiveAllocator       = roleHas(ALLOCATOR_ROLE(), allocator);
    uint256 roleMemberCountBefore = roleMemberCount(ALLOCATOR_ROLE());
    uint256 roleMemberPosBefore   = roleMemberPos(ALLOCATOR_ROLE(), allocator);

    removeAllocator@withrevert(e, allocator);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsFreezer;
    bool revert3 = !isLiveAllocator;
    // Out of bounds swap in EnumerableSet.remove (unreachable given roleMemberPosIndexed)
    bool revert4 = isLiveAllocator && roleMemberPosBefore > roleMemberCountBefore;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4;
}
