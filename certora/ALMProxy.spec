// ALMProxy.spec

import "ALMProxyBase.spec";

// --- Methods block ---

methods {
    function CONTROLLER() external returns (bytes32) envfree;

    // doDelegateCall is left unresolved: the Prover then lets it rewrite the proxy's storage
    // arbitrarily, which is its real semantics
}

// doCall and doCallWithValue are gated by CONTROLLER
override definition callerRole() returns bytes32 = CONTROLLER();

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

// --- Ghosts and hooks ---

// Delegatecalls issued by the proxy: how many, the last target, and whether the last one failed
persistent ghost mathint delegateCalls;
persistent ghost address delegateTarget;
persistent ghost bool    delegateFailed;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (executingContract == currentContract) {
        delegateCalls  = delegateCalls + 1;
        delegateTarget = addr;
        delegateFailed = rc == 0;
    }
}

// --- Storage Affected Rule ---

// Roles only change through the AccessControl functions, or through doDelegateCall, whose target
// runs with the proxy's storage and can rewrite anything
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
        f.selector == sig:doDelegateCall(address, bytes).selector;
    assert roleAdmin(anyRole) != roleAdminBefore =>
        f.selector == sig:doDelegateCall(address, bytes).selector;
}

// --- Controller functions: doDelegateCall ---

// The proxy delegatecalls the target exactly once.
//
// Unlike doCall, this does not prove that `data` reaches the target unchanged: the Prover cannot
// route a delegatecall with arbitrary calldata to a mock's code (a dispatcher that resolves to a
// fallback is unsupported for delegatecalls), and hooks cannot read the calldata from memory.
rule doDelegateCall(address target, bytes data) {
    env e;

    require delegateCalls == 0;

    doDelegateCall(e, target, data);

    assert delegateCalls  == 1;
    assert delegateTarget == target;
}

// The target is assumed to be a contract: for a codeless target, OpenZeppelin's Address reverts
// only if the call also returned no data, which the Prover's unresolved call does not pin down
rule doDelegateCall_revert(address target, bytes data) {
    env e;

    require nativeCodesize[target] > 0;
    require !delegateFailed;

    bool senderIsController = roleHas(CONTROLLER(), e.msg.sender);

    doDelegateCall@withrevert(e, target, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = !senderIsController;
    bool revert3 = delegateFailed;

    assert lastReverted <=> revert1 || revert2 || revert3;
}
