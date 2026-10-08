// AccessControls.spec

// --- Methods block ---

methods {
    // AccessControl getters
    function DEFAULT_ADMIN_ROLE()      external returns (bytes32) envfree;
    function hasRole(bytes32, address) external returns (bool)    envfree;
    function getRoleAdmin(bytes32)     external returns (bytes32) envfree;
    function supportsInterface(bytes4) external returns (bool)    envfree;

    // AccessControlEnumerable getters
    function getRoleMember(bytes32, uint256) external returns (address) envfree;
    function getRoleMemberCount(bytes32)     external returns (uint256) envfree;
}

// --- Definitions ---

// ERC-165 interface ids: IAccessControls, IAccessControlEnumerable, IAccessControl, IERC165
definition IACCESS_CONTROLS_ID()           returns bytes4 = to_bytes4(0x1fb1c936);
definition IACCESS_CONTROL_ENUMERABLE_ID() returns bytes4 = to_bytes4(0x5a05180f);
definition IACCESS_CONTROL_ID()            returns bytes4 = to_bytes4(0x7965db0b);
definition IERC165_ID()                    returns bytes4 = to_bytes4(0x01ffc9a7);

// --- Storage accessors (direct storage access) ---

// AccessControl._roles[role].hasRole[account] / .adminRole
definition roleHas(bytes32 role, address account) returns bool    = currentContract._roles[role].hasRole[account];
definition roleAdmin(bytes32 role)                returns bytes32 = currentContract._roles[role].adminRole;

// AccessControlEnumerable._roleMembers[role]._inner._values / ._positions
// (AddressSet stores each account as bytes32(uint256(uint160(account))))
definition roleMemberCount(bytes32 role)                 returns uint256 = currentContract._roleMembers[role]._inner._values.length;
definition roleMemberAt(bytes32 role, uint256 i)         returns bytes32 = currentContract._roleMembers[role]._inner._values[i];
definition roleMemberPosRaw(bytes32 role, bytes32 value) returns uint256 = currentContract._roleMembers[role]._inner._positions[value];
definition roleMemberPos(bytes32 role, address account)  returns uint256 = roleMemberPosRaw(role, to_bytes32(account));

// --- Invariants: AccessControlEnumerable ---

// hasRole and membership in the enumerable set always agree
invariant roleMembershipConsistency(bytes32 role, address account)
    roleHas(role, account) <=> roleMemberPos(role, account) != 0
    {
        preserved grantRole(bytes32 role_, address other) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require roleMemberCount(role) < max_uint256;
        }
        preserved revokeRole(bytes32 role_, address other) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
        }
        preserved renounceRole(bytes32 role_, address callerConfirmation) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
        }
    }

// Every stored member is an address (no high bits set)
invariant roleMemberIsAddress(bytes32 role, uint256 i)
    i < roleMemberCount(role) => (exists address a. roleMemberAt(role, i) == to_bytes32(a))
    {
        preserved revokeRole(bytes32 role_, address other) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberIsAddress(role, lastIdx);
        }
        preserved renounceRole(bytes32 role_, address callerConfirmation) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberIsAddress(role, lastIdx);
        }
    }

// _roleMembers set: values[i] has position i + 1
invariant roleMemberAtIsMember(bytes32 role, uint256 i)
    i < roleMemberCount(role) => roleMemberPosRaw(role, roleMemberAt(role, i)) == i + 1
    {
        preserved revokeRole(bytes32 role_, address other) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
        }
        preserved renounceRole(bytes32 role_, address callerConfirmation) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
        }
    }

// _roleMembers set: a member with position p + 1 is stored at values[p]
invariant roleMemberPosIndexed(bytes32 role, bytes32 value, uint256 p)
    roleMemberPosRaw(role, value) == p + 1 => p < roleMemberCount(role) && roleMemberAt(role, p) == value
    {
        preserved grantRole(bytes32 role_, address other) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require roleMemberCount(role) < max_uint256;
        }
        preserved revokeRole(bytes32 role_, address other) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            uint256 otherIdx;
            require roleMemberPos(role, other) == 0 || otherIdx + 1 == roleMemberPos(role, other);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
            requireInvariant roleMemberPosIndexed(role, to_bytes32(other), otherIdx);
        }
        preserved renounceRole(bytes32 role_, address callerConfirmation) with (env e) {
            uint256 lastIdx;
            require roleMemberCount(role) == 0 || lastIdx + 1 == roleMemberCount(role);
            uint256 senderIdx;
            require roleMemberPos(role, e.msg.sender) == 0 || senderIdx + 1 == roleMemberPos(role, e.msg.sender);
            requireInvariant roleMemberAtIsMember(role, lastIdx);
            requireInvariant roleMemberPosIndexed(role, to_bytes32(e.msg.sender), senderIdx);
        }
    }

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

// --- View function correctness ---

rule DEFAULT_ADMIN_ROLE_correctness() {
    assert DEFAULT_ADMIN_ROLE() == to_bytes32(0);
}

rule hasRole_correctness(bytes32 role, address account) {
    assert hasRole(role, account) == roleHas(role, account);
}

rule getRoleAdmin_correctness(bytes32 role) {
    assert getRoleAdmin(role) == roleAdmin(role);
}

rule getRoleMemberCount_correctness(bytes32 role) {
    assert getRoleMemberCount(role) == roleMemberCount(role);
}

rule getRoleMember_correctness(bytes32 role, uint256 index) {
    require index < roleMemberCount(role);
    // The stored value is a plain address, so the uint160 truncation in the getter is lossless
    requireInvariant roleMemberIsAddress(role, index);

    address member = getRoleMember(role, index);

    assert to_bytes32(member) == roleMemberAt(role, index);
}

rule getRoleMember_revert(bytes32 role, uint256 index) {
    uint256 count = roleMemberCount(role);

    getRoleMember@withrevert(role, index);

    bool revert1 = index >= count;

    assert lastReverted <=> revert1;
}

rule supportsInterface_correctness(bytes4 interfaceId) {
    bool result = supportsInterface(interfaceId);

    assert result <=>
        interfaceId == IACCESS_CONTROLS_ID()           ||
        interfaceId == IACCESS_CONTROL_ENUMERABLE_ID() ||
        interfaceId == IACCESS_CONTROL_ID()            ||
        interfaceId == IERC165_ID();
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

// --- Access control functions: grantRole ---

rule grantRole(bytes32 role, address account) {
    env e;

    bool    hasRoleBefore         = roleHas(role, account);
    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, account);

    // The set is only extended when the role is newly granted and the account is not yet a member
    bool addedToSet = !hasRoleBefore && roleMemberPosBefore == 0;

    // Avoid overflow of the set length
    require roleMemberCountBefore < max_uint256;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;
    uint256 otherIdx;
    require roleMemberCountBefore == 0 || otherIdx < roleMemberCountBefore;

    bool    otherHasRoleBefore     = roleHas(otherRole, otherAccount);
    uint256 otherMemberCountBefore = roleMemberCount(otherRole);
    uint256 otherMemberPosBefore   = roleMemberPos(otherRole, otherAccount);
    bytes32 otherMemberAtBefore    = roleMemberAt(role, otherIdx);

    grantRole(e, role, account);

    // The account holds the role
    assert roleHas(role, account);
    // Not added: the set is untouched
    assert !addedToSet => roleMemberCount(role)        == roleMemberCountBefore;
    assert !addedToSet => roleMemberPos(role, account) == roleMemberPosBefore;
    // Added: appended to the set
    assert addedToSet => roleMemberCount(role)        == roleMemberCountBefore + 1;
    assert addedToSet => roleMemberPos(role, account) == roleMemberCountBefore + 1;
    assert addedToSet => roleMemberAt(role, roleMemberCountBefore) == to_bytes32(account);
    // Other (role, account) pairs are untouched
    assert roleHas(otherRole, otherAccount)       == otherHasRoleBefore;
    assert roleMemberPos(otherRole, otherAccount) == otherMemberPosBefore;
    assert otherRole != role => roleMemberCount(otherRole) == otherMemberCountBefore;
    assert otherIdx < roleMemberCountBefore => roleMemberAt(role, otherIdx) == otherMemberAtBefore;
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

// The account holds the role and is a member of the set: swap and pop
rule revokeRole(bytes32 role, address account) {
    env e;

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

    revokeRole(e, role, account);

    // The account no longer holds the role and is removed from the set
    assert !roleHas(role, account);
    assert roleMemberPos(role, account) == 0;
    assert roleMemberCount(role)        == roleMemberCountBefore - 1;
    // The last member takes the removed slot (unless it was the removed one)
    assert idx != lastIdx => roleMemberAt(role, idx)             == lastMember;
    assert idx != lastIdx => roleMemberPosRaw(role, lastMember)  == roleMemberPosBefore;
    // Other (role, account) pairs are untouched
    assert roleHas(otherRole, otherAccount)       == otherHasRoleBefore;
    assert roleMemberPos(otherRole, otherAccount) == otherMemberPosBefore;
    assert otherRole != role => roleMemberCount(otherRole) == otherMemberCountBefore;
    assert otherIdx < lastIdx => roleMemberAt(role, otherIdx) == otherMemberAtBefore;
}

// The account does not hold the role, or is not a member of the set: nothing but hasRole changes
rule revokeRole_notMember(bytes32 role, address account) {
    env e;

    bool    hasRoleBefore         = roleHas(role, account);
    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, account);

    require !hasRoleBefore || roleMemberPosBefore == 0;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;
    uint256 otherIdx;
    require roleMemberCountBefore == 0 || otherIdx < roleMemberCountBefore;

    bool    otherHasRoleBefore     = roleHas(otherRole, otherAccount);
    uint256 otherMemberCountBefore = roleMemberCount(otherRole);
    uint256 otherMemberPosBefore   = roleMemberPos(otherRole, otherAccount);
    bytes32 otherMemberAtBefore    = roleMemberAt(role, otherIdx);

    revokeRole(e, role, account);

    assert !roleHas(role, account);
    assert roleMemberPos(role, account) == roleMemberPosBefore;
    assert roleMemberCount(role)        == roleMemberCountBefore;
    assert roleHas(otherRole, otherAccount)       == otherHasRoleBefore;
    assert roleMemberPos(otherRole, otherAccount) == otherMemberPosBefore;
    assert roleMemberCount(otherRole)             == otherMemberCountBefore;
    assert otherIdx < roleMemberCountBefore => roleMemberAt(role, otherIdx) == otherMemberAtBefore;
}

rule revokeRole_revert(bytes32 role, address account) {
    env e;

    bool    senderIsRoleAdmin     = roleHas(roleAdmin(role), e.msg.sender);
    bool    hasRoleBefore         = roleHas(role, account);
    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, account);

    revokeRole@withrevert(e, role, account);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsRoleAdmin;
    // Out of bounds swap in EnumerableSet.remove (unreachable given roleMemberPosIndexed)
    bool revert3 = hasRoleBefore && roleMemberPosBefore > roleMemberCountBefore;

    assert lastReverted <=> revert1 || revert2 || revert3;
}

// --- Access control functions: renounceRole ---

// The sender holds the role and is a member of the set: swap and pop
rule renounceRole(bytes32 role, address callerConfirmation) {
    env e;

    address account = e.msg.sender;

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

    renounceRole(e, role, callerConfirmation);

    // The sender no longer holds the role and is removed from the set
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

// The sender does not hold the role, or is not a member of the set: nothing but hasRole changes
rule renounceRole_notMember(bytes32 role, address callerConfirmation) {
    env e;

    address account = e.msg.sender;

    bool    hasRoleBefore         = roleHas(role, account);
    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, account);

    require !hasRoleBefore || roleMemberPosBefore == 0;

    bytes32 otherRole;
    address otherAccount;
    require otherRole != role || otherAccount != account;
    uint256 otherIdx;
    require roleMemberCountBefore == 0 || otherIdx < roleMemberCountBefore;

    bool    otherHasRoleBefore     = roleHas(otherRole, otherAccount);
    uint256 otherMemberCountBefore = roleMemberCount(otherRole);
    uint256 otherMemberPosBefore   = roleMemberPos(otherRole, otherAccount);
    bytes32 otherMemberAtBefore    = roleMemberAt(role, otherIdx);

    renounceRole(e, role, callerConfirmation);

    assert !roleHas(role, account);
    assert roleMemberPos(role, account) == roleMemberPosBefore;
    assert roleMemberCount(role)        == roleMemberCountBefore;
    assert roleHas(otherRole, otherAccount)       == otherHasRoleBefore;
    assert roleMemberPos(otherRole, otherAccount) == otherMemberPosBefore;
    assert roleMemberCount(otherRole)             == otherMemberCountBefore;
    assert otherIdx < roleMemberCountBefore => roleMemberAt(role, otherIdx) == otherMemberAtBefore;
}

rule renounceRole_revert(bytes32 role, address callerConfirmation) {
    env e;

    bool    hasRoleBefore         = roleHas(role, e.msg.sender);
    uint256 roleMemberCountBefore = roleMemberCount(role);
    uint256 roleMemberPosBefore   = roleMemberPos(role, e.msg.sender);

    renounceRole@withrevert(e, role, callerConfirmation);

    bool revert1 = e.msg.value > 0;
    bool revert2 = callerConfirmation != e.msg.sender;
    // Out of bounds swap in EnumerableSet.remove (unreachable given roleMemberPosIndexed)
    bool revert3 = hasRoleBefore && roleMemberPosBefore > roleMemberCountBefore;

    assert lastReverted <=> revert1 || revert2 || revert3;
}

