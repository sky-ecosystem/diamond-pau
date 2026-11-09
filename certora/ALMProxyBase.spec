// ALMProxyBase.spec
//
// Rules shared by ALMProxy and ALMProxyFreezable: AccessControlEnumerable (imported), the two call
// forwarders and receive. The forwarders are gated by a different role in each contract, given by
// `callerRole`, which every importing spec overrides. Rules are only verified where they are `use`d.

import "AccessControlEnumerableBase.spec";

using MockCallTarget as callTarget;

// --- Methods block ---

methods {
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

// MockCallTarget storage
definition targetShouldRevert() returns bool    = callTarget.shouldRevert;
definition targetCalls()        returns uint256 = callTarget.calls;
definition targetLastSender()   returns address = callTarget.lastSender;
definition targetLastValue()    returns uint256 = callTarget.lastValue;
definition targetLastDataHash() returns bytes32 = callTarget.lastDataHash;

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
