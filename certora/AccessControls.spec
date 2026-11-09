// AccessControls.spec

import "AccessControlEnumerableBase.spec";

// --- Definitions ---

// ERC-165 interface id: IAccessControls, supported on top of the AccessControlEnumerable ones
definition IACCESS_CONTROLS_ID() returns bytes4 = to_bytes4(0x1fb1c936);

override definition extraInterfaceId(bytes4 interfaceId) returns bool = interfaceId == IACCESS_CONTROLS_ID();

// --- Shared rules ---

use invariant roleMembershipConsistency;
use invariant roleMemberIsAddress;
use invariant roleMemberAtIsMember;
use invariant roleMemberPosIndexed;

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

// --- Storage Affected Rule ---

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

    assert roleAdmin(anyRole) != roleAdminBefore =>
        f.selector == sig:setRoleAdmin(bytes32, bytes32).selector;

    assert roleHas(anyRole, anyAccount) != hasRoleBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;
    assert roleMemberCountAfter != roleMemberCountBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;
    assert roleMemberAtAfter != roleMemberAtBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;
    assert roleMemberPosRaw(anyRole, anyValue) != roleMemberPosBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;
}

// --- Admin functions: setRoleAdmin ---

rule setRoleAdmin(bytes32 role, bytes32 adminRole) {
    env e;

    bytes32 otherRole;
    require otherRole != role;

    bytes32 otherRoleAdminBefore = roleAdmin(otherRole);

    setRoleAdmin(e, role, adminRole);

    assert roleAdmin(role)      == adminRole;
    assert roleAdmin(otherRole) == otherRoleAdminBefore;
}

rule setRoleAdmin_revert(bytes32 role, bytes32 adminRole) {
    env e;

    bool senderIsAdmin = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    setRoleAdmin@withrevert(e, role, adminRole);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsAdmin;

    assert lastReverted <=> revert1 || revert2;
}
