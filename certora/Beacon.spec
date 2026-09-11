// Beacon.spec

using Beacon as beacon;
using ConfigValidator as configValidator;

// --- Methods block ---

methods {
    // AccessControl getters
    function DEFAULT_ADMIN_ROLE()      external returns (bytes32) envfree;
    function hasRole(bytes32, address) external returns (bool)    envfree;
    function getRoleAdmin(bytes32)     external returns (bytes32) envfree;

    // AccessControlEnumerable getters
    function getRoleMember(bytes32, uint256) external returns (address) envfree;
    function getRoleMemberCount(bytes32)     external returns (uint256) envfree;

    // Beacon view functions
    function integrations()            external returns (IEnumerableIntegrations.Integration[]) envfree;
    function getConfig(bytes32)        external returns (IEnumerableIntegrations.Config)        envfree;
    function getConfigs(bytes32[])     external returns (IEnumerableIntegrations.Config[])      envfree;
    function getDispatch(bytes4)       external returns (IEnumerableIntegrations.Dispatch)      envfree;
    function getDispatches(bytes4[])   external returns (IEnumerableIntegrations.Dispatch[])    envfree;
    function supportsInterface(bytes4) external returns (bool)                                  envfree;

    // ConfigValidator: solc-side ABI validation of a calldata Config
    function configValidator.isWellFormed(IEnumerableIntegrations.Config) external returns (bool) envfree;
}

// --- Definitions ---

// ReentrancyGuard states
definition NOT_ENTERED() returns uint256 = 1;
definition ENTERED()     returns uint256 = 2;

// ERC-165 interface ids: IBeacon, IAccessControlEnumerable, IAccessControl, IERC165
definition IBEACON_ID()                    returns bytes4 = to_bytes4(0x480e03c0);
definition IACCESS_CONTROL_ENUMERABLE_ID() returns bytes4 = to_bytes4(0x5a05180f);
definition IACCESS_CONTROL_ID()            returns bytes4 = to_bytes4(0x7965db0b);
definition IERC165_ID()                    returns bytes4 = to_bytes4(0x01ffc9a7);

// IController selectors that can never be wired. The Beacon does not implement them, so the
// values are given explicitly: updateIntegrations(bytes32[]), removeIntegrations(bytes32[]),
// accessControls(), beacon(), proxy(), rateLimits()
definition UPDATE_INTEGRATIONS_SEL() returns bytes4 = to_bytes4(0xaf666640);
definition REMOVE_INTEGRATIONS_SEL() returns bytes4 = to_bytes4(0x339a441f);
definition ACCESS_CONTROLS_SEL()     returns bytes4 = to_bytes4(0x748365ef);
definition BEACON_SEL()              returns bytes4 = to_bytes4(0x59659e90);
definition PROXY_SEL()               returns bytes4 = to_bytes4(0xec556889);
definition RATE_LIMITS_SEL()         returns bytes4 = to_bytes4(0xf0921594);

// Mirrors Beacon._revertIfCallSelectorIsHardcoded
definition isHardcoded(bytes4 sel) returns bool =
    sel == to_bytes4(sig:integrations().selector)          ||
    sel == to_bytes4(sig:getConfig(bytes32).selector)      ||
    sel == to_bytes4(sig:getConfigs(bytes32[]).selector)   ||
    sel == to_bytes4(sig:getDispatch(bytes4).selector)     ||
    sel == to_bytes4(sig:getDispatches(bytes4[]).selector) ||
    sel == UPDATE_INTEGRATIONS_SEL()                       ||
    sel == REMOVE_INTEGRATIONS_SEL()                       ||
    sel == ACCESS_CONTROLS_SEL()                           ||
    sel == BEACON_SEL()                                    ||
    sel == PROXY_SEL()                                     ||
    sel == RATE_LIMITS_SEL();

// --- Storage accessors (direct storage access, one per storage slot family) ---

// ReentrancyGuard._status
definition status() returns uint256 = currentContract._status;

// AccessControl._roles[role].hasRole[account] / .adminRole
definition roleHas(bytes32 role, address account) returns bool    = currentContract._roles[role].hasRole[account];
definition roleAdmin(bytes32 role)                returns bytes32 = currentContract._roles[role].adminRole;

// AccessControlEnumerable._roleMembers[role]._inner._values / ._positions
// (AddressSet stores each account as bytes32(uint256(uint160(account))))
definition roleMemberCount(bytes32 role)                 returns uint256 = currentContract._roleMembers[role]._inner._values.length;
definition roleMemberAt(bytes32 role, uint256 i)         returns bytes32 = currentContract._roleMembers[role]._inner._values[i];
definition roleMemberPosRaw(bytes32 role, bytes32 value) returns uint256 = currentContract._roleMembers[role]._inner._positions[value];
definition roleMemberPos(bytes32 role, address account)  returns uint256 = roleMemberPosRaw(role, to_bytes32(account));

// Beacon._integrationIds._inner._values / ._positions
definition integrationCount()         returns uint256 = currentContract._integrationIds._inner._values.length;
definition integrationAt(uint256 i)   returns bytes32 = currentContract._integrationIds._inner._values[i];
definition integrationPos(bytes32 id) returns uint256 = currentContract._integrationIds._inner._positions[id];

// Beacon._configs[id].facet / .wires
definition configFacet(bytes32 id)                     returns address = currentContract._configs[id].facet;
definition wireCount(bytes32 id)                       returns uint256 = currentContract._configs[id].wires.length;
definition wireCallSelector(bytes32 id, uint256 i)     returns bytes4  = currentContract._configs[id].wires[i].callSelector;
definition wireDelegateSelector(bytes32 id, uint256 i) returns bytes4  = currentContract._configs[id].wires[i].delegateSelector;

// Beacon._dispatches[sel].facet / .delegateSelector
definition dispatchFacet(bytes4 sel)            returns address = currentContract._dispatches[sel].facet;
definition dispatchDelegateSelector(bytes4 sel) returns bytes4  = currentContract._dispatches[sel].delegateSelector;

// True if `sel` is the call selector of one of the wires currently stored for `id`
definition storedWireIn(bytes32 id, bytes4 sel) returns bool =
    exists uint256 j. j < wireCount(id) && wireCallSelector(id, j) == sel;

// True if `sel` is the call selector of one of the wires of the calldata `config`
definition configWireIn(IEnumerableIntegrations.Config config, bytes4 sel) returns bool =
    exists uint256 j. j < config.wires.length && config.wires[j].callSelector == sel;

// --- Invariants: ReentrancyGuard ---

// The reentrancy guard is always released at rest
invariant statusNotEntered()
    status() == NOT_ENTERED();

// --- Invariants: AccessControl ---

// Beacon never calls _setRoleAdmin: every role is administered by DEFAULT_ADMIN_ROLE
invariant roleAdminIsDefaultAdmin(bytes32 role)
    roleAdmin(role) == to_bytes32(0);

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

// --- Invariants: Beacon ---

// _integrationIds set: values[i] has position i + 1
invariant integrationAtIsMember(uint256 i)
    i < integrationCount() => integrationPos(integrationAt(i)) == i + 1
    {
        preserved removeIntegration(bytes32 other) with (env e) {
            uint256 lastIdx;
            require integrationCount() == 0 || lastIdx + 1 == integrationCount();
            requireInvariant integrationAtIsMember(lastIdx);
        }
    }

// _integrationIds set: a member with position p + 1 is stored at values[p]
invariant integrationPosIndexed(bytes32 id, uint256 p)
    integrationPos(id) == p + 1 => p < integrationCount() && integrationAt(p) == id
    {
        preserved setIntegration(bytes32 other, IEnumerableIntegrations.Config config) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require integrationCount() < max_uint256;
        }
        preserved removeIntegration(bytes32 other) with (env e) {
            uint256 lastIdx;
            require integrationCount() == 0 || lastIdx + 1 == integrationCount();
            uint256 otherIdx;
            require integrationPos(other) == 0 || otherIdx + 1 == integrationPos(other);
            requireInvariant integrationAtIsMember(lastIdx);
            requireInvariant integrationPosIndexed(other, otherIdx);
        }
    }

// An integration is registered iff it has a facet iff it has wires
invariant integrationConfigConsistency(bytes32 id)
    (integrationPos(id) != 0 <=> configFacet(id) != 0) &&
    (configFacet(id) != 0 <=> wireCount(id) != 0)
    {
        preserved setIntegration(bytes32 other, IEnumerableIntegrations.Config config) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require integrationCount() < max_uint256;
        }
        preserved removeIntegration(bytes32 other) with (env e) {
            uint256 lastIdx;
            require integrationCount() == 0 || lastIdx + 1 == integrationCount();
            requireInvariant integrationAtIsMember(lastIdx);
        }
    }

// Every stored wire is reflected in the dispatch table with the integration's facet
invariant wireDispatchConsistency(bytes32 id, uint256 i)
    i < wireCount(id) =>
        dispatchFacet(wireCallSelector(id, i))            == configFacet(id) &&
        dispatchDelegateSelector(wireCallSelector(id, i)) == wireDelegateSelector(id, i)
    {
        preserved setIntegration(bytes32 other, IEnumerableIntegrations.Config config) with (env e) {
            requireInvariant integrationConfigConsistency(id);
            // wireSelectorUniqueness(id, i, other, k) for every k (proven below)
            require forall uint256 k. (k < wireCount(other) && (id != other || i != k)) =>
                wireCallSelector(id, i) != wireCallSelector(other, k);
        }
        preserved removeIntegration(bytes32 other) with (env e) {
            // wireSelectorUniqueness(id, i, other, k) for every k (proven below)
            require forall uint256 k. (k < wireCount(other) && (id != other || i != k)) =>
                wireCallSelector(id, i) != wireCallSelector(other, k);
        }
    }

// No call selector is wired twice, neither across integrations nor within one
invariant wireSelectorUniqueness(bytes32 id1, uint256 i, bytes32 id2, uint256 j)
    (i < wireCount(id1) && j < wireCount(id2) && (id1 != id2 || i != j)) =>
        wireCallSelector(id1, i) != wireCallSelector(id2, j)
    {
        preserved setIntegration(bytes32 other, IEnumerableIntegrations.Config config) with (env e) {
            requireInvariant integrationConfigConsistency(id1);
            requireInvariant integrationConfigConsistency(id2);
            requireInvariant wireDispatchConsistency(id1, i);
            requireInvariant wireDispatchConsistency(id2, j);
            // wireSelectorUniqueness(id1, k, id2, j) and (id2, k, id1, i) for every k
            require forall uint256 k. (k < wireCount(id1) && (id1 != id2 || k != j)) =>
                wireCallSelector(id1, k) != wireCallSelector(id2, j);
            require forall uint256 k. (k < wireCount(id2) && (id2 != id1 || k != i)) =>
                wireCallSelector(id2, k) != wireCallSelector(id1, i);
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
    bytes32 anyId;
    uint256 anyIntegrationIdx;
    uint256 anyWireIdx;
    bytes4  anySel;

    // Element reads are pinned inside the arrays
    require anyMemberIdx      < roleMemberCount(anyRole);
    require anyIntegrationIdx < integrationCount();
    require anyWireIdx        < wireCount(anyId);

    // ReentrancyGuard
    uint256 statusBefore = status();

    // AccessControl
    bool    hasRoleBefore   = roleHas(anyRole, anyAccount);
    bytes32 roleAdminBefore = roleAdmin(anyRole);

    // AccessControlEnumerable
    uint256 roleMemberCountBefore = roleMemberCount(anyRole);
    bytes32 roleMemberAtBefore    = roleMemberAt(anyRole, anyMemberIdx);
    uint256 roleMemberPosBefore   = roleMemberPosRaw(anyRole, anyValue);

    // Beacon._integrationIds
    uint256 integrationCountBefore = integrationCount();
    bytes32 integrationAtBefore    = integrationAt(anyIntegrationIdx);
    uint256 integrationPosBefore   = integrationPos(anyId);

    // Beacon._configs
    address configFacetBefore          = configFacet(anyId);
    uint256 wireCountBefore            = wireCount(anyId);
    bytes4  wireCallSelectorBefore     = wireCallSelector(anyId, anyWireIdx);
    bytes4  wireDelegateSelectorBefore = wireDelegateSelector(anyId, anyWireIdx);

    // Beacon._dispatches
    address dispatchFacetBefore            = dispatchFacet(anySel);
    bytes4  dispatchDelegateSelectorBefore = dispatchDelegateSelector(anySel);

    f(e, args);

    uint256 statusAfter = status();

    bool    hasRoleAfter   = roleHas(anyRole, anyAccount);
    bytes32 roleAdminAfter = roleAdmin(anyRole);

    uint256 roleMemberCountAfter = roleMemberCount(anyRole);
    uint256 roleMemberPosAfter   = roleMemberPosRaw(anyRole, anyValue);

    uint256 integrationCountAfter = integrationCount();
    uint256 integrationPosAfter   = integrationPos(anyId);

    address configFacetAfter = configFacet(anyId);
    uint256 wireCountAfter   = wireCount(anyId);

    address dispatchFacetAfter            = dispatchFacet(anySel);
    bytes4  dispatchDelegateSelectorAfter = dispatchDelegateSelector(anySel);

    // Element reads after the call are only meaningful while still in range
    bool memberIdxInRange      = anyMemberIdx      < roleMemberCountAfter;
    bool integrationIdxInRange = anyIntegrationIdx < integrationCountAfter;
    bool wireIdxInRange        = anyWireIdx        < wireCountAfter;

    bytes32 roleMemberAtAfter         = memberIdxInRange      ? roleMemberAt(anyRole, anyMemberIdx)     : roleMemberAtBefore;
    bytes32 integrationAtAfter        = integrationIdxInRange ? integrationAt(anyIntegrationIdx)        : integrationAtBefore;
    bytes4  wireCallSelectorAfter     = wireIdxInRange        ? wireCallSelector(anyId, anyWireIdx)     : wireCallSelectorBefore;
    bytes4  wireDelegateSelectorAfter = wireIdxInRange        ? wireDelegateSelector(anyId, anyWireIdx) : wireDelegateSelectorBefore;

    // nonReentrant rewrites the status to NOT_ENTERED on exit (see statusNotEntered)
    assert statusAfter != statusBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;

    // Role admins are never changed
    assert roleAdminAfter == roleAdminBefore;

    assert hasRoleAfter != hasRoleBefore =>
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
    assert roleMemberPosAfter != roleMemberPosBefore =>
        f.selector == sig:grantRole(bytes32, address).selector ||
        f.selector == sig:revokeRole(bytes32, address).selector ||
        f.selector == sig:renounceRole(bytes32, address).selector;

    assert integrationCountAfter != integrationCountBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert integrationAtAfter != integrationAtBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert integrationPosAfter != integrationPosBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;

    assert configFacetAfter != configFacetBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert wireCountAfter != wireCountBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert wireCallSelectorAfter != wireCallSelectorBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert wireDelegateSelectorAfter != wireDelegateSelectorBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;

    assert dispatchFacetAfter != dispatchFacetBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
    assert dispatchDelegateSelectorAfter != dispatchDelegateSelectorBefore =>
        f.selector == sig:setIntegration(bytes32, IEnumerableIntegrations.Config).selector ||
        f.selector == sig:removeIntegration(bytes32).selector;
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

rule getConfig_correctness(bytes32 id) {
    uint256 i;
    require i < wireCount(id);

    IEnumerableIntegrations.Config config = getConfig(id);

    assert config.facet        == configFacet(id);
    assert config.wires.length == wireCount(id);
    assert config.wires[i].callSelector     == wireCallSelector(id, i);
    assert config.wires[i].delegateSelector == wireDelegateSelector(id, i);
}

rule getConfigs_correctness(bytes32[] ids) {
    uint256 i;
    require i < ids.length;
    uint256 k;
    require k < wireCount(ids[i]);

    IEnumerableIntegrations.Config[] configs = getConfigs(ids);

    assert configs.length == ids.length;
    assert configs[i].facet        == configFacet(ids[i]);
    assert configs[i].wires.length == wireCount(ids[i]);
    assert configs[i].wires[k].callSelector     == wireCallSelector(ids[i], k);
    assert configs[i].wires[k].delegateSelector == wireDelegateSelector(ids[i], k);
}

rule getDispatch_correctness(bytes4 callSelector) {
    IEnumerableIntegrations.Dispatch dispatch = getDispatch(callSelector);

    assert dispatch.facet            == dispatchFacet(callSelector);
    assert dispatch.delegateSelector == dispatchDelegateSelector(callSelector);
}

rule getDispatches_correctness(bytes4[] callSelectors) {
    uint256 i;
    require i < callSelectors.length;

    IEnumerableIntegrations.Dispatch[] dispatches = getDispatches(callSelectors);

    assert dispatches.length == callSelectors.length;
    assert dispatches[i].facet            == dispatchFacet(callSelectors[i]);
    assert dispatches[i].delegateSelector == dispatchDelegateSelector(callSelectors[i]);
}

rule integrations_correctness() {
    uint256 i;
    require i < integrationCount();
    bytes32 id = integrationAt(i);
    uint256 k;
    require k < wireCount(id);

    IEnumerableIntegrations.Integration[] integrations_ = integrations();

    assert integrations_.length == integrationCount();
    assert integrations_[i].id                  == id;
    assert integrations_[i].config.facet        == configFacet(id);
    assert integrations_[i].config.wires.length == wireCount(id);
    assert integrations_[i].config.wires[k].callSelector     == wireCallSelector(id, k);
    assert integrations_[i].config.wires[k].delegateSelector == wireDelegateSelector(id, k);
}

rule supportsInterface_correctness(bytes4 interfaceId) {
    bool result = supportsInterface(interfaceId);

    assert result <=>
        interfaceId == IBEACON_ID()                    ||
        interfaceId == IACCESS_CONTROL_ENUMERABLE_ID() ||
        interfaceId == IACCESS_CONTROL_ID()            ||
        interfaceId == IERC165_ID();
}

// --- Admin functions: setIntegration ---

rule setIntegration(bytes32 id, IEnumerableIntegrations.Config config) {
    env e;

    // Stale wires for an unregistered id would be appended to instead of replaced
    requireInvariant integrationConfigConsistency(id);

    uint256 integrationCountBefore = integrationCount();
    uint256 integrationPosBefore   = integrationPos(id);
    uint256 wireCountBefore        = wireCount(id);

    // Avoid overflow of the set length
    require integrationCountBefore < max_uint256;

    // A wire of the new config
    uint256 i;
    require i < config.wires.length;
    bytes4 newSel = config.wires[i].callSelector;

    // A wire of the previously stored config (if any)
    uint256 j;
    require wireCountBefore == 0 || j < wireCountBefore;
    bytes4 oldSel        = wireCallSelector(id, j);
    bool   oldSelRewired = configWireIn(config, oldSel);

    // Another integration and one of its stored wires (if any)
    bytes32 otherId;
    require otherId != id;
    uint256 otherIdx;
    require integrationCountBefore == 0 || otherIdx < integrationCountBefore;
    uint256 otherWireIdx;
    require wireCount(otherId) == 0 || otherWireIdx < wireCount(otherId);

    // A selector that is neither in the old nor in the new wires
    bytes4 otherSel;
    require !configWireIn(config, otherSel);
    require !storedWireIn(id, otherSel);

    uint256 otherPosBefore              = integrationPos(otherId);
    bytes32 otherIntegrationBefore      = integrationAt(otherIdx);
    address otherFacetBefore            = configFacet(otherId);
    uint256 otherWireCountBefore        = wireCount(otherId);
    bytes4  otherCallSelectorBefore     = wireCallSelector(otherId, otherWireIdx);
    bytes4  otherDelegateSelectorBefore = wireDelegateSelector(otherId, otherWireIdx);
    address otherDispatchFacetBefore            = dispatchFacet(otherSel);
    bytes4  otherDispatchDelegateSelectorBefore = dispatchDelegateSelector(otherSel);

    setIntegration(e, id, config);

    // _integrationIds: already registered, the set is untouched
    assert integrationPosBefore != 0 => integrationCount() == integrationCountBefore;
    assert integrationPosBefore != 0 => integrationPos(id) == integrationPosBefore;
    // _integrationIds: new integration, appended to the set
    assert integrationPosBefore == 0 => integrationCount() == integrationCountBefore + 1;
    assert integrationPosBefore == 0 => integrationPos(id) == integrationCountBefore + 1;
    assert integrationPosBefore == 0 => integrationAt(integrationCountBefore) == id;
    // _configs: the stored config is exactly the given one
    assert configFacet(id) == config.facet;
    assert wireCount(id)   == config.wires.length;
    assert wireCallSelector(id, i)     == config.wires[i].callSelector;
    assert wireDelegateSelector(id, i) == config.wires[i].delegateSelector;
    // _dispatches: new wires are dispatched to the new facet
    assert dispatchFacet(newSel)            == config.facet;
    assert dispatchDelegateSelector(newSel) == config.wires[i].delegateSelector;
    // _dispatches: old wires that were not re-wired are cleared
    assert j < wireCountBefore && !oldSelRewired => dispatchFacet(oldSel)            == 0;
    assert j < wireCountBefore && !oldSelRewired => dispatchDelegateSelector(oldSel) == to_bytes4(0);
    // Other integrations and unrelated selectors are untouched
    assert integrationPos(otherId) == otherPosBefore;
    assert otherIdx < integrationCountBefore => integrationAt(otherIdx) == otherIntegrationBefore;
    assert configFacet(otherId) == otherFacetBefore;
    assert wireCount(otherId)   == otherWireCountBefore;
    assert otherWireIdx < otherWireCountBefore => wireCallSelector(otherId, otherWireIdx)     == otherCallSelectorBefore;
    assert otherWireIdx < otherWireCountBefore => wireDelegateSelector(otherId, otherWireIdx) == otherDelegateSelectorBefore;
    assert dispatchFacet(otherSel)            == otherDispatchFacetBefore;
    assert dispatchDelegateSelector(otherSel) == otherDispatchDelegateSelectorBefore;
}

rule setIntegration_revert(bytes32 id, IEnumerableIntegrations.Config config) {
    env e;

    // Clean malformed calldata for Config structure
    require configValidator.isWellFormed(config);

    uint256 statusBefore  = status();
    bool    senderIsAdmin = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);
    uint256 facetCodeSize = nativeCodesize[config.facet];

    // The stored wires (and their dispatches) are deleted first only if the id is registered
    bool deletesStoredWires = integrationPos(id) != 0;

    // A call selector of the new config that is hardcoded
    bool anyHardcoded = exists uint256 i.
        i < config.wires.length && isHardcoded(config.wires[i].callSelector);

    // A call selector of the new config that is already dispatched and not cleared beforehand
    bool anyAlreadyWired = exists uint256 i.
        i < config.wires.length &&
        dispatchFacet(config.wires[i].callSelector) != 0 &&
        !(deletesStoredWires && storedWireIn(id, config.wires[i].callSelector));

    // A call selector that appears twice in the new config
    bool anyDuplicate = exists uint256 i. exists uint256 j.
        i < j && j < config.wires.length &&
        config.wires[i].callSelector == config.wires[j].callSelector;

    setIntegration@withrevert(e, id, config);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = config.facet == 0;
    bool revert5 = facetCodeSize == 0;
    bool revert6 = config.wires.length == 0;
    bool revert7 = anyHardcoded;
    bool revert8 = anyAlreadyWired;
    bool revert9 = anyDuplicate;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 ||
                            revert6 || revert7 || revert8 || revert9;
}

// --- Admin functions: removeIntegration ---

rule removeIntegration(bytes32 id) {
    env e;

    uint256 integrationCountBefore = integrationCount();
    uint256 integrationPosBefore   = integrationPos(id);

    // Swap and pop bookkeeping
    uint256 idx;
    require idx + 1 == integrationPosBefore;
    uint256 lastIdx;
    require lastIdx + 1 == integrationCountBefore;
    bytes32 lastId = integrationAt(lastIdx);
    // The last member is either the removed one or another consistent member
    requireInvariant integrationAtIsMember(lastIdx);

    // A stored wire of the removed integration
    uint256 j;
    require j < wireCount(id);
    bytes4 oldSel = wireCallSelector(id, j);

    // Another integration, its slot in the set (if any) and one of its wires (if any)
    bytes32 otherId;
    require otherId != id && otherId != lastId;
    uint256 otherIdx;
    require otherIdx != idx;
    require lastIdx == 0 || otherIdx < lastIdx;
    uint256 otherWireIdx;
    require wireCount(otherId) == 0 || otherWireIdx < wireCount(otherId);

    // A selector that is not one of the removed wires
    bytes4 otherSel;
    require !storedWireIn(id, otherSel);

    uint256 otherPosBefore              = integrationPos(otherId);
    bytes32 otherIntegrationBefore      = integrationAt(otherIdx);
    address otherFacetBefore            = configFacet(otherId);
    uint256 otherWireCountBefore        = wireCount(otherId);
    bytes4  otherCallSelectorBefore     = wireCallSelector(otherId, otherWireIdx);
    bytes4  otherDelegateSelectorBefore = wireDelegateSelector(otherId, otherWireIdx);
    address otherDispatchFacetBefore            = dispatchFacet(otherSel);
    bytes4  otherDispatchDelegateSelectorBefore = dispatchDelegateSelector(otherSel);

    removeIntegration(e, id);

    // _integrationIds: removed from the set
    assert integrationPos(id) == 0;
    assert integrationCount() == integrationCountBefore - 1;
    // _integrationIds: the last member takes the removed slot (unless it was the removed one)
    assert idx != lastIdx => integrationAt(idx)     == lastId;
    assert idx != lastIdx => integrationPos(lastId) == integrationPosBefore;
    // _configs: the config is cleared
    assert configFacet(id) == 0;
    assert wireCount(id)   == 0;
    // _dispatches: old wires are cleared
    assert dispatchFacet(oldSel)            == 0;
    assert dispatchDelegateSelector(oldSel) == to_bytes4(0);
    // Other integrations and unrelated selectors are untouched
    assert integrationPos(otherId) == otherPosBefore;
    assert otherIdx < lastIdx => integrationAt(otherIdx) == otherIntegrationBefore;
    assert configFacet(otherId) == otherFacetBefore;
    assert wireCount(otherId)   == otherWireCountBefore;
    assert otherWireIdx < otherWireCountBefore => wireCallSelector(otherId, otherWireIdx)     == otherCallSelectorBefore;
    assert otherWireIdx < otherWireCountBefore => wireDelegateSelector(otherId, otherWireIdx) == otherDelegateSelectorBefore;
    assert dispatchFacet(otherSel)            == otherDispatchFacetBefore;
    assert dispatchDelegateSelector(otherSel) == otherDispatchDelegateSelectorBefore;
}

rule removeIntegration_revert(bytes32 id) {
    env e;

    uint256 statusBefore           = status();
    bool    senderIsAdmin          = roleHas(DEFAULT_ADMIN_ROLE(), e.msg.sender);
    uint256 integrationCountBefore = integrationCount();
    uint256 integrationPosBefore   = integrationPos(id);

    removeIntegration@withrevert(e, id);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = integrationPosBefore == 0;
    // Out of bounds swap in EnumerableSet.remove (unreachable given integrationPosIndexed)
    bool revert5 = integrationPosBefore > integrationCountBefore;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
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
