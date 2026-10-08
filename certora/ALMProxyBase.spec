// ALMProxyBase.spec
//
// Rules shared by ALMProxy and ALMProxyFreezable: AccessControl, the two call forwarders and
// receive. The forwarders are gated by a different role in each contract, given by `callerRole`,
// which every importing spec overrides. Rules are only verified where they are `use`d.

using MockCallTarget as callTarget;

// --- Methods block ---

methods {
    // AccessControl
    function DEFAULT_ADMIN_ROLE()      external returns (bytes32) envfree;
    function hasRole(bytes32, address) external returns (bool)    envfree;
    function getRoleAdmin(bytes32)     external returns (bytes32) envfree;
    function supportsInterface(bytes4) external returns (bool)    envfree;

    // doCall and doCallWithValue forward an arbitrary call. A call to the mock target is dispatched
    // to it, so its effects are observed; a call to any other address is modelled as having no
    // effect on the proxy (no reentrancy into the proxy).
    unresolved external in _.doCall(address, bytes) => DISPATCH(optimistic=false, use_fallback=true) [
        MockCallTarget._
    ] default NONDET;
    unresolved external in _.doCallWithValue(address, bytes, uint256) => DISPATCH(optimistic=false, use_fallback=true) [
        MockCallTarget._
    ] default NONDET;
}

// --- Definitions ---

// The role that gates doCall and doCallWithValue, overridden by every importing spec
definition callerRole() returns bytes32 = to_bytes32(0);

// ERC-165 interface ids: IAccessControl, IERC165
definition IACCESS_CONTROL_ID() returns bytes4 = to_bytes4(0x7965db0b);
definition IERC165_ID()         returns bytes4 = to_bytes4(0x01ffc9a7);

// AccessControl._roles[role].hasRole[account] / .adminRole
definition roleHas(bytes32 role, address account) returns bool    = currentContract._roles[role].hasRole[account];
definition roleAdmin(bytes32 role)                returns bytes32 = currentContract._roles[role].adminRole;

// MockCallTarget storage
definition targetShouldRevert() returns bool    = callTarget.shouldRevert;
definition targetCalls()        returns uint256 = callTarget.calls;
definition targetLastSender()   returns address = callTarget.lastSender;
definition targetLastValue()    returns uint256 = callTarget.lastValue;
definition targetLastDataHash() returns bytes32 = callTarget.lastDataHash;

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

// --- Proxy calls: doCall ---

// The call reaches the target once, from the proxy, with the exact calldata and no value
rule doCall(bytes data) {
    env e;

    uint256 callsBefore = targetCalls();

    // The mock's call counter is unchecked: keep it from wrapping
    require callsBefore < max_uint256;

    doCall(e, callTarget, data);

    assert targetCalls()        == callsBefore + 1;
    assert targetLastSender()   == currentContract;
    assert targetLastValue()    == 0;
    assert targetLastDataHash() == keccak256(data);
}

rule doCall_revert(bytes data) {
    env e;

    bool senderIsCaller     = roleHas(callerRole(), e.msg.sender);
    bool shouldRevert       = targetShouldRevert();

    doCall@withrevert(e, callTarget, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsCaller;
    bool revert3 = shouldRevert;

    assert lastReverted <=> revert1 || revert2 || revert3;
}

// --- Proxy calls: doCallWithValue ---

// The call reaches the target once, from the proxy, with the exact calldata and value, and the
// value leaves the proxy's balance (which first receives msg.value)
rule doCallWithValue(bytes data, uint256 value) {
    env e;

    require e.msg.sender != currentContract && e.msg.sender != callTarget;

    uint256 callsBefore         = targetCalls();

    // The mock's call counter is unchecked: keep it from wrapping
    require callsBefore < max_uint256;
    mathint proxyBalanceBefore  = nativeBalances[currentContract];
    mathint targetBalanceBefore = nativeBalances[callTarget];

    doCallWithValue(e, callTarget, data, value);

    assert targetCalls()        == callsBefore + 1;
    assert targetLastSender()   == currentContract;
    assert targetLastValue()    == value;
    assert targetLastDataHash() == keccak256(data);

    assert nativeBalances[currentContract] == proxyBalanceBefore + e.msg.value - value;
    assert nativeBalances[callTarget]      == targetBalanceBefore + value;
}

rule doCallWithValue_revert(bytes data, uint256 value) {
    env e;

    require e.msg.sender != currentContract;
    require nativeBalances[e.msg.sender] >= e.msg.value;
    require nativeBalances[currentContract] + e.msg.value <= max_uint256;
    require nativeBalances[callTarget] + value <= max_uint256;

    bool    senderIsCaller     = roleHas(callerRole(), e.msg.sender);
    bool    shouldRevert       = targetShouldRevert();
    mathint available          = nativeBalances[currentContract] + e.msg.value;

    doCallWithValue@withrevert(e, callTarget, data, value);

    bool revert1 = !senderIsCaller;
    bool revert2 = available < value;
    bool revert3 = shouldRevert;

    assert lastReverted <=> revert1 || revert2 || revert3;
}

// --- Receive ---

// Plain ETH transfers are accepted and only credit the proxy
rule receiveETH(method f) filtered { f -> f.isFallback } {
    env e;
    calldataarg args;

    require e.msg.sender != currentContract;

    mathint balanceBefore = nativeBalances[currentContract];

    f(e, args);

    assert nativeBalances[currentContract] == balanceBefore + e.msg.value;
}
