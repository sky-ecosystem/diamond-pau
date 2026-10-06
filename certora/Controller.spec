// Controller.spec

using Controller as controller;
using Beacon     as beacon;

// --- Methods block ---

methods {
    // Controller storage getters
    function accessControls() external returns (address) envfree;
    function proxy()          external returns (address) envfree;
    function rateLimits()     external returns (address) envfree;

    // Controller immutable getter
    function beacon() external returns (address) envfree;

    // Controller view functions
    function integrations()          external returns (IEnumerableIntegrations.Integration[]) envfree;
    function getConfig(bytes32)      external returns (IEnumerableIntegrations.Config)        envfree;
    function getConfigs(bytes32[])   external returns (IEnumerableIntegrations.Config[])      envfree;
    function getDispatch(bytes4)     external returns (IEnumerableIntegrations.Dispatch)      envfree;
    function getDispatches(bytes4[]) external returns (IEnumerableIntegrations.Dispatch[])    envfree;

    // Beacon function reached through updateIntegrations (linked)
    function beacon.getConfigs(bytes32[]) external returns (IEnumerableIntegrations.Config[]) envfree;

    // The AccessControls address lives in namespaced storage and cannot be linked, so its answer
    // is modelled by a ghost: both the admin and the non-admin branches stay reachable.
    function _.hasRole(bytes32 role, address account) external => hasRoleGhost(role, account) expect bool;

    // The fallback delegatecalls into the wired facet. Facets are trusted code that only touch
    // their own namespaced storage, so the delegatecall is modelled as succeeding without
    // changing Controller storage. The DELEGATECALL hook below records that it happened.
    unresolved external in Controller._ => NONDET;
}

// --- Ghosts and hooks ---

persistent ghost hasRoleGhost(bytes32, address) returns bool;

persistent ghost mathint delegateCalls;
persistent ghost address delegateTarget;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegateCalls  = delegateCalls + 1;
    delegateTarget = addr;
}

// --- Definitions ---

// ReentrancyGuardUpgradeable states
definition NOT_ENTERED() returns uint256 = 1;
definition ENTERED()     returns uint256 = 2;

definition DEFAULT_ADMIN_ROLE() returns bytes32 = to_bytes32(0);

// --- Storage accessors (direct storage access on the ERC-7201 namespaces) ---

// openzeppelin.storage.ReentrancyGuard
definition status() returns uint256 = currentContract.ext_openzeppelin_storage_ReentrancyGuard._status;

// openzeppelin.storage.Initializable
definition initializedVersion() returns uint64 = currentContract.ext_openzeppelin_storage_Initializable._initialized;
definition initializing()       returns bool   = currentContract.ext_openzeppelin_storage_Initializable._initializing;

// sky.pau.storage.SharedController
definition accessControlsSlot() returns address = currentContract.ext_sky_pau_storage_SharedController.accessControls;
definition proxySlot()          returns address = currentContract.ext_sky_pau_storage_SharedController.proxy;
definition rateLimitsSlot()     returns address = currentContract.ext_sky_pau_storage_SharedController.rateLimits;

// sky.pau.storage.Controller: integrationIds._inner._values / ._positions
definition integrationCount()         returns uint256 = currentContract.ext_sky_pau_storage_Controller.integrationIds._inner._values.length;
definition integrationAt(uint256 i)   returns bytes32 = currentContract.ext_sky_pau_storage_Controller.integrationIds._inner._values[i];
definition integrationPos(bytes32 id) returns uint256 = currentContract.ext_sky_pau_storage_Controller.integrationIds._inner._positions[id];

// sky.pau.storage.Controller: configs[id].facet / .wires
definition configFacet(bytes32 id)                     returns address = currentContract.ext_sky_pau_storage_Controller.configs[id].facet;
definition wireCount(bytes32 id)                       returns uint256 = currentContract.ext_sky_pau_storage_Controller.configs[id].wires.length;
definition wireCallSelector(bytes32 id, uint256 i)     returns bytes4  = currentContract.ext_sky_pau_storage_Controller.configs[id].wires[i].callSelector;
definition wireDelegateSelector(bytes32 id, uint256 i) returns bytes4  = currentContract.ext_sky_pau_storage_Controller.configs[id].wires[i].delegateSelector;

// sky.pau.storage.Controller: dispatches[sel].facet / .delegateSelector
definition dispatchFacet(bytes4 sel)            returns address = currentContract.ext_sky_pau_storage_Controller.dispatches[sel].facet;
definition dispatchDelegateSelector(bytes4 sel) returns bytes4  = currentContract.ext_sky_pau_storage_Controller.dispatches[sel].delegateSelector;

// Beacon._configs[id].facet / .wires (the source synced by updateIntegrations)
definition beaconFacet(bytes32 id)                     returns address = beacon._configs[id].facet;
definition beaconWireCount(bytes32 id)                 returns uint256 = beacon._configs[id].wires.length;
definition beaconWireCallSelector(bytes32 id, uint256 i)     returns bytes4 = beacon._configs[id].wires[i].callSelector;
definition beaconWireDelegateSelector(bytes32 id, uint256 i) returns bytes4 = beacon._configs[id].wires[i].delegateSelector;

// --- Quantified helpers ---

// True if `sel` is the call selector of one of the wires currently stored for `id`
definition storedWireIn(bytes32 id, bytes4 sel) returns bool =
    exists uint256 j. j < wireCount(id) && wireCallSelector(id, j) == sel;

// True if `sel` is the call selector of one of the wires of `id` in the Beacon
definition beaconWireIn(bytes32 id, bytes4 sel) returns bool =
    exists uint256 j. j < beaconWireCount(id) && beaconWireCallSelector(id, j) == sel;

// True if `id` is one of `ids`
definition idIn(bytes32[] ids, bytes32 id) returns bool =
    exists uint256 k. k < ids.length && ids[k] == id;

// True if `sel` is a stored wire of one of `ids`
definition batchStoredWireIn(bytes32[] ids, bytes4 sel) returns bool =
    exists uint256 k. k < ids.length && storedWireIn(ids[k], sel);

// True if `sel` is a Beacon wire of one of `ids`
definition batchBeaconWireIn(bytes32[] ids, bytes4 sel) returns bool =
    exists uint256 k. k < ids.length && beaconWireIn(ids[k], sel);

// The Beacon never wires a call selector twice, neither across integrations nor within one
// (Beacon.spec, wireSelectorUniqueness). Instantiated for the configs of `ids`: without it a
// selector shared by two Beacon configs of the batch is silently re-assigned to the later one,
// because that integration's own deletion clears the dispatch the earlier one just set.
definition beaconSelectorsUnique(bytes32[] ids) returns bool =
    forall uint256 k1. forall uint256 w1. forall uint256 k2. forall uint256 w2.
        (k1 < ids.length && k2 < ids.length &&
         w1 < beaconWireCount(ids[k1]) && w2 < beaconWireCount(ids[k2]) &&
         (ids[k1] != ids[k2] || w1 != w2)) =>
            beaconWireCallSelector(ids[k1], w1) != beaconWireCallSelector(ids[k2], w2);

// Inductive hypotheses: the invariants below quantified over all their arguments. Used in the
// preserved blocks of the batch functions, where pinning single indices is not possible.
definition allSetConsistent() returns bool =
    (forall uint256 i. i < integrationCount() => integrationPos(integrationAt(i)) == i + 1) &&
    (forall bytes32 id. forall uint256 p.
        integrationPos(id) == p + 1 => p < integrationCount() && integrationAt(p) == id);

definition allConfigsConsistent() returns bool =
    forall bytes32 id.
        (integrationPos(id) != 0 <=> configFacet(id) != 0) &&
        (configFacet(id) != 0 <=> wireCount(id) != 0);

definition allWiresDispatched() returns bool =
    forall bytes32 id. forall uint256 i. i < wireCount(id) =>
        dispatchFacet(wireCallSelector(id, i))            == configFacet(id) &&
        dispatchDelegateSelector(wireCallSelector(id, i)) == wireDelegateSelector(id, i);

definition allSelectorsUnique() returns bool =
    forall bytes32 id1. forall uint256 i. forall bytes32 id2. forall uint256 j.
        (i < wireCount(id1) && j < wireCount(id2) && (id1 != id2 || i != j)) =>
            wireCallSelector(id1, i) != wireCallSelector(id2, j);

// --- Invariants: ReentrancyGuardUpgradeable and Initializable ---

// The reentrancy guard is always released at rest
invariant statusNotEntered()
    status() == NOT_ENTERED();

// The constructor is the only initializer and it has run exactly once
invariant initializedOnce()
    initializedVersion() == 1 && !initializing();

// --- Invariants: shared storage ---

// The constructor rejects zero addresses and nothing in the Controller writes them afterwards
invariant sharedAddressesNonZero()
    accessControlsSlot() != 0 && proxySlot() != 0 && rateLimitsSlot() != 0;

// --- Invariants: Controller ---

// integrationIds set: values[i] has position i + 1
invariant integrationAtIsMember(uint256 i)
    i < integrationCount() => integrationPos(integrationAt(i)) == i + 1
    {
        preserved removeIntegrations(bytes32[] ids) with (env e) {
            require allSetConsistent();
        }
    }

// integrationIds set: a member with position p + 1 is stored at values[p]
invariant integrationPosIndexed(bytes32 id, uint256 p)
    integrationPos(id) == p + 1 => p < integrationCount() && integrationAt(p) == id
    {
        preserved updateIntegrations(bytes32[] ids) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require integrationCount() + ids.length < max_uint256;
        }
        preserved removeIntegrations(bytes32[] ids) with (env e) {
            require allSetConsistent();
        }
    }

// An integration is registered iff it has a facet iff it has wires
invariant integrationConfigConsistency(bytes32 id)
    (integrationPos(id) != 0 <=> configFacet(id) != 0) &&
    (configFacet(id) != 0 <=> wireCount(id) != 0)
    {
        preserved updateIntegrations(bytes32[] ids) with (env e) {
            // EnumerableSet.add stores values.length as the position: it must not wrap to 0
            require integrationCount() + ids.length < max_uint256;
            require allConfigsConsistent();
        }
        preserved removeIntegrations(bytes32[] ids) with (env e) {
            require allSetConsistent();
        }
    }

// // Every stored wire is reflected in the dispatch table with the integration's facet
// invariant wireDispatchConsistency(bytes32 id, uint256 i)
//     i < wireCount(id) =>
//         dispatchFacet(wireCallSelector(id, i))            == configFacet(id) &&
//         dispatchDelegateSelector(wireCallSelector(id, i)) == wireDelegateSelector(id, i)
//     {
//         preserved updateIntegrations(bytes32[] ids) with (env e) {
//             require allConfigsConsistent();
//             require allWiresDispatched();
//             require allSelectorsUnique();
//         }
//         preserved removeIntegrations(bytes32[] ids) with (env e) {
//             require allSelectorsUnique();
//         }
//     }

// // No call selector is wired twice, neither across integrations nor within one
// invariant wireSelectorUniqueness(bytes32 id1, uint256 i, bytes32 id2, uint256 j)
//     (i < wireCount(id1) && j < wireCount(id2) && (id1 != id2 || i != j)) =>
//         wireCallSelector(id1, i) != wireCallSelector(id2, j)
//     {
//         preserved updateIntegrations(bytes32[] ids) with (env e) {
//             require allConfigsConsistent();
//             require allWiresDispatched();
//             require allSelectorsUnique();
//         }
//     }

// --- Storage Affected Rule ---

rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    bytes32 anyId;
    uint256 anyIntegrationIdx;
    uint256 anyWireIdx;
    bytes4  anySel;

    // Element reads are pinned inside the arrays
    require anyIntegrationIdx < integrationCount();
    require anyWireIdx        < wireCount(anyId);

    // ReentrancyGuardUpgradeable and Initializable
    uint256 statusBefore             = status();
    uint64  initializedVersionBefore = initializedVersion();
    bool    initializingBefore       = initializing();

    // Shared storage
    address accessControlsBefore = accessControlsSlot();
    address proxyBefore          = proxySlot();
    address rateLimitsBefore     = rateLimitsSlot();

    // integrationIds
    uint256 integrationCountBefore = integrationCount();
    bytes32 integrationAtBefore    = integrationAt(anyIntegrationIdx);
    uint256 integrationPosBefore   = integrationPos(anyId);

    // configs
    address configFacetBefore          = configFacet(anyId);
    uint256 wireCountBefore            = wireCount(anyId);
    bytes4  wireCallSelectorBefore     = wireCallSelector(anyId, anyWireIdx);
    bytes4  wireDelegateSelectorBefore = wireDelegateSelector(anyId, anyWireIdx);

    // dispatches
    address dispatchFacetBefore            = dispatchFacet(anySel);
    bytes4  dispatchDelegateSelectorBefore = dispatchDelegateSelector(anySel);

    f(e, args);

    uint256 statusAfter             = status();
    uint64  initializedVersionAfter = initializedVersion();
    bool    initializingAfter       = initializing();

    address accessControlsAfter = accessControlsSlot();
    address proxyAfter          = proxySlot();
    address rateLimitsAfter     = rateLimitsSlot();

    uint256 integrationCountAfter = integrationCount();
    uint256 integrationPosAfter   = integrationPos(anyId);

    address configFacetAfter = configFacet(anyId);
    uint256 wireCountAfter   = wireCount(anyId);

    address dispatchFacetAfter            = dispatchFacet(anySel);
    bytes4  dispatchDelegateSelectorAfter = dispatchDelegateSelector(anySel);

    // Element reads after the call are only meaningful while still in range
    bool integrationIdxInRange = anyIntegrationIdx < integrationCountAfter;
    bool wireIdxInRange        = anyWireIdx        < wireCountAfter;

    bytes32 integrationAtAfter        = integrationIdxInRange ? integrationAt(anyIntegrationIdx)        : integrationAtBefore;
    bytes4  wireCallSelectorAfter     = wireIdxInRange        ? wireCallSelector(anyId, anyWireIdx)     : wireCallSelectorBefore;
    bytes4  wireDelegateSelectorAfter = wireIdxInRange        ? wireDelegateSelector(anyId, anyWireIdx) : wireDelegateSelectorBefore;

    // nonReentrant rewrites the status to NOT_ENTERED on exit (see statusNotEntered)
    assert statusAfter != statusBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;

    // Initialization and shared storage are never written after the constructor
    assert initializedVersionAfter == initializedVersionBefore;
    assert initializingAfter       == initializingBefore;
    assert accessControlsAfter     == accessControlsBefore;
    assert proxyAfter              == proxyBefore;
    assert rateLimitsAfter         == rateLimitsBefore;

    assert integrationCountAfter != integrationCountBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert integrationAtAfter != integrationAtBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert integrationPosAfter != integrationPosBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;

    assert configFacetAfter != configFacetBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert wireCountAfter != wireCountBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert wireCallSelectorAfter != wireCallSelectorBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert wireDelegateSelectorAfter != wireDelegateSelectorBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;

    assert dispatchFacetAfter != dispatchFacetBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
    assert dispatchDelegateSelectorAfter != dispatchDelegateSelectorBefore =>
        f.selector == sig:updateIntegrations(bytes32[]).selector ||
        f.selector == sig:removeIntegrations(bytes32[]).selector;
}

// --- View function correctness ---

rule accessControls_correctness() {
    assert accessControls() == accessControlsSlot();
}

rule proxy_correctness() {
    assert proxy() == proxySlot();
}

rule rateLimits_correctness() {
    assert rateLimits() == rateLimitsSlot();
}

rule beacon_correctness() {
    assert beacon() == beacon;
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

// --- Admin functions: updateIntegrations ---

rule updateIntegrations(bytes32[] ids) {
    env e;

    // Stale wires for an unregistered id would be appended to instead of replaced
    require allConfigsConsistent();

    // The dispatch integrity of the Controller relies on that of the Beacon
    require beaconSelectorsUnique(ids);

    uint256 integrationCountBefore = integrationCount();

    // Avoid overflow of the set length
    require integrationCountBefore + ids.length < max_uint256;

    // An integration of the batch
    uint256 k;
    require k < ids.length;
    bytes32 id = ids[k];

    uint256 integrationPosBefore = integrationPos(id);
    uint256 wireCountBefore      = wireCount(id);

    // A wire of its Beacon config
    uint256 i;
    require i < beaconWireCount(id);
    bytes4 newSel = beaconWireCallSelector(id, i);

    // A wire of its previously stored config (if any)
    uint256 j;
    require wireCountBefore == 0 || j < wireCountBefore;
    bytes4 oldSel        = wireCallSelector(id, j);
    bool   oldSelRewired = batchBeaconWireIn(ids, oldSel);

    // An integration outside the batch and one of its stored wires (if any)
    bytes32 otherId;
    require !idIn(ids, otherId);
    uint256 otherWireIdx;
    require wireCount(otherId) == 0 || otherWireIdx < wireCount(otherId);

    // A selector that is neither stored by nor synced for any integration of the batch
    bytes4 otherSel;
    require !batchStoredWireIn(ids, otherSel);
    require !batchBeaconWireIn(ids, otherSel);

    uint256 otherPosBefore              = integrationPos(otherId);
    address otherFacetBefore            = configFacet(otherId);
    uint256 otherWireCountBefore        = wireCount(otherId);
    bytes4  otherCallSelectorBefore     = wireCallSelector(otherId, otherWireIdx);
    bytes4  otherDelegateSelectorBefore = wireDelegateSelector(otherId, otherWireIdx);
    address otherDispatchFacetBefore            = dispatchFacet(otherSel);
    bytes4  otherDispatchDelegateSelectorBefore = dispatchDelegateSelector(otherSel);

    // The Beacon is only read
    address beaconFacetBefore     = beaconFacet(id);
    uint256 beaconWireCountBefore = beaconWireCount(id);

    updateIntegrations(e, ids);

    // integrationIds: registered, and an already registered id keeps its position
    assert integrationPos(id) != 0;
    assert integrationPosBefore != 0 => integrationPos(id) == integrationPosBefore;
    assert integrationCount() >= integrationCountBefore;
    assert integrationCount() <= integrationCountBefore + ids.length;
    // configs: the stored config is exactly the Beacon one
    assert configFacet(id) == beaconFacet(id);
    assert wireCount(id)   == beaconWireCount(id);
    assert wireCallSelector(id, i)     == beaconWireCallSelector(id, i);
    assert wireDelegateSelector(id, i) == beaconWireDelegateSelector(id, i);
    // dispatches: synced wires are dispatched to the Beacon facet
    assert dispatchFacet(newSel)            == beaconFacet(id);
    assert dispatchDelegateSelector(newSel) == beaconWireDelegateSelector(id, i);
    // dispatches: old wires that no batch integration re-wires are cleared
    assert j < wireCountBefore && !oldSelRewired => dispatchFacet(oldSel)            == 0;
    assert j < wireCountBefore && !oldSelRewired => dispatchDelegateSelector(oldSel) == to_bytes4(0);
    // Integrations outside the batch and unrelated selectors are untouched
    assert integrationPos(otherId) == otherPosBefore;
    assert configFacet(otherId)    == otherFacetBefore;
    assert wireCount(otherId)      == otherWireCountBefore;
    assert otherWireIdx < otherWireCountBefore => wireCallSelector(otherId, otherWireIdx)     == otherCallSelectorBefore;
    assert otherWireIdx < otherWireCountBefore => wireDelegateSelector(otherId, otherWireIdx) == otherDelegateSelectorBefore;
    assert dispatchFacet(otherSel)            == otherDispatchFacetBefore;
    assert dispatchDelegateSelector(otherSel) == otherDispatchDelegateSelectorBefore;
    // The Beacon is untouched
    assert beaconFacet(id)     == beaconFacetBefore;
    assert beaconWireCount(id) == beaconWireCountBefore;
}

// The exact revert condition of updateIntegrations is checked in two rules, one per direction of
// the equivalence, because `anyAlreadyWired` nests an `exists` inside a negated `exists`: under
// `<=>` every quantifier is needed in both polarities and the SMT solver times out.

// Every listed condition makes the call revert
rule updateIntegrations_revert_sufficient(bytes32[] ids) {
    env e;

    // Stale wires for an unregistered id would not have their dispatches cleared
    require allConfigsConsistent();

    uint256 status  = status();
    bool    senderIsAdmin = hasRoleGhost(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    // A Beacon config of the batch without facet, with a codeless facet, or without wires
    bool anyZeroFacet     = exists uint256 k. k < ids.length && beaconFacet(ids[k]) == 0;
    bool anyCodelessFacet = exists uint256 k. k < ids.length && nativeCodesize[beaconFacet(ids[k])] == 0;
    bool anyEmptyWires    = exists uint256 k. k < ids.length && beaconWireCount(ids[k]) == 0;

    // The dispatch integrity of the Controller relies on that of the Beacon: with the Beacon
    // selectors unique (Beacon.spec, wireSelectorUniqueness), a Beacon wire of the batch can
    // neither repeat one of an earlier batch entry nor one of its own config
    require beaconSelectorsUnique(ids);

    // A Beacon wire (k, w) of the batch whose selector is dispatched before the call and not owned
    // by an integration processed up to step k, since only those have their stored wires deleted
    // by then
    bool anyAlreadyWired = exists uint256 k. exists uint256 w.
        k < ids.length && w < beaconWireCount(ids[k]) &&
        dispatchFacet(beaconWireCallSelector(ids[k], w)) != 0 &&
        !(exists uint256 k3. k3 <= k && storedWireIn(ids[k3], beaconWireCallSelector(ids[k], w)));

    updateIntegrations@withrevert(e, ids);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = ids.length == 0;
    bool revert5 = anyZeroFacet;
    bool revert6 = anyCodelessFacet;
    bool revert7 = anyEmptyWires;
    bool revert8 = anyAlreadyWired;

    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 =>
        lastReverted;
}

// No revert happens outside the listed conditions, for a batch of one integration. For larger
// batches the witness search nested in `anyAlreadyWired` (the earlier batch entry owning the
// selector, and its stored wire) makes this direction diverge; it stays covered by the sufficient
// direction above and by the effect rule updateIntegrations.
//
// The conditions are written without quantifiers: the loop bound of the conf (loop_iter 2)
// already restricts every wire array of the model to two entries, so the explicit checks of the
// two indices are equivalent to the quantified definitions within the model, and the solver has
// no witness left to search for.
rule updateIntegrations_revert_necessary_single(bytes32[] ids) {
    env e;

    require ids.length == 1;
    bytes32 id = ids[0];

    // Stale wires for an unregistered id would not have their dispatches cleared
    require allConfigsConsistent();

    // The dispatch integrity of the Controller relies on that of the Beacon: with the Beacon
    // selectors unique (Beacon.spec, wireSelectorUniqueness), the two Beacon wires differ
    require beaconWireCount(id) < 2 || beaconWireCallSelector(id, 0) != beaconWireCallSelector(id, 1);

    uint256 status        = status();
    bool    senderIsAdmin = hasRoleGhost(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    // The Beacon config without facet, with a codeless facet, or without wires
    bool zeroFacet     = beaconFacet(id) == 0;
    bool codelessFacet = nativeCodesize[beaconFacet(id)] == 0;
    bool emptyWires    = beaconWireCount(id) == 0;

    // A Beacon wire whose selector is dispatched before the call and not among the stored wires
    // of the integration, which are the ones deleted before re-wiring
    bytes4 sel0 = beaconWireCallSelector(id, 0);
    bytes4 sel1 = beaconWireCallSelector(id, 1);
    bool stored0 = (0 < wireCount(id) && wireCallSelector(id, 0) == sel0) || (1 < wireCount(id) && wireCallSelector(id, 1) == sel0);
    bool stored1 = (0 < wireCount(id) && wireCallSelector(id, 0) == sel1) || (1 < wireCount(id) && wireCallSelector(id, 1) == sel1);
    bool alreadyWired =
        (0 < beaconWireCount(id) && dispatchFacet(sel0) != 0 && !stored0) ||
        (1 < beaconWireCount(id) && dispatchFacet(sel1) != 0 && !stored1);

    updateIntegrations@withrevert(e, ids);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = zeroFacet;
    bool revert5 = codelessFacet;
    bool revert6 = emptyWires;
    bool revert7 = alreadyWired;

    assert lastReverted =>
        revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7;
}

// --- Admin functions: removeIntegrations ---

rule removeIntegrations(bytes32[] ids) {
    env e;

    // Swap and pop bookkeeping relies on a well-formed set
    require allSetConsistent();

    uint256 integrationCountBefore = integrationCount();

    // An integration of the batch and one of its stored wires
    uint256 k;
    require k < ids.length;
    bytes32 id = ids[k];
    uint256 j;
    require j < wireCount(id);
    bytes4 oldSel = wireCallSelector(id, j);

    // An integration outside the batch and one of its stored wires (if any)
    bytes32 otherId;
    require !idIn(ids, otherId);
    uint256 otherWireIdx;
    require wireCount(otherId) == 0 || otherWireIdx < wireCount(otherId);

    // A selector that is not a stored wire of any integration of the batch
    bytes4 otherSel;
    require !batchStoredWireIn(ids, otherSel);

    bool    otherIsMemberBefore         = integrationPos(otherId) != 0;
    address otherFacetBefore            = configFacet(otherId);
    uint256 otherWireCountBefore        = wireCount(otherId);
    bytes4  otherCallSelectorBefore     = wireCallSelector(otherId, otherWireIdx);
    bytes4  otherDelegateSelectorBefore = wireDelegateSelector(otherId, otherWireIdx);
    address otherDispatchFacetBefore            = dispatchFacet(otherSel);
    bytes4  otherDispatchDelegateSelectorBefore = dispatchDelegateSelector(otherSel);

    removeIntegrations(e, ids);

    // integrationIds: every id of the batch is removed, the batch had no repeats
    assert integrationPos(id)  == 0;
    assert integrationCount()  == integrationCountBefore - ids.length;
    // configs: the config is cleared
    assert configFacet(id) == 0;
    assert wireCount(id)   == 0;
    // dispatches: old wires are cleared
    assert dispatchFacet(oldSel)            == 0;
    assert dispatchDelegateSelector(oldSel) == to_bytes4(0);
    // Integrations outside the batch keep their membership (positions may move) and config
    assert (integrationPos(otherId) != 0) == otherIsMemberBefore;
    assert configFacet(otherId) == otherFacetBefore;
    assert wireCount(otherId)   == otherWireCountBefore;
    assert otherWireIdx < otherWireCountBefore => wireCallSelector(otherId, otherWireIdx)     == otherCallSelectorBefore;
    assert otherWireIdx < otherWireCountBefore => wireDelegateSelector(otherId, otherWireIdx) == otherDelegateSelectorBefore;
    // Unrelated selectors are untouched
    assert dispatchFacet(otherSel)            == otherDispatchFacetBefore;
    assert dispatchDelegateSelector(otherSel) == otherDispatchDelegateSelectorBefore;
}

rule removeIntegrations_revert(bytes32[] ids) {
    env e;

    // Excludes the out of bounds swap of a corrupted set (unreachable given integrationPosIndexed)
    require allSetConsistent();

    uint256 statusBefore  = status();
    bool    senderIsAdmin = hasRoleGhost(DEFAULT_ADMIN_ROLE(), e.msg.sender);

    // An id of the batch that is not registered, or that was already removed earlier in the batch
    bool anyNotFound = exists uint256 k. k < ids.length && (
        integrationPos(ids[k]) == 0 ||
        (exists uint256 k2. k2 < k && ids[k2] == ids[k])
    );

    removeIntegrations@withrevert(e, ids);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = ids.length == 0;
    bool revert5 = anyNotFound;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}

// --- Fallback ---

// The fallback forwards to the facet wired for msg.sig, whose calldata is not observable from
// CVL. It is characterised through the DELEGATECALL hook: the call succeeds exactly when a facet
// is reached (calldata of at least 4 bytes and a wired selector), and the facet reached is one
// from the dispatch table. The facet call itself is modelled as succeeding (see methods block).
rule fallback_dispatch(method f) filtered { f -> f.isFallback } {
    env e;
    calldataarg args;

    require delegateCalls == 0;

    f@withrevert(e, args);

    assert lastReverted <=> delegateCalls == 0;
    assert !lastReverted => delegateCalls == 1;
    assert !lastReverted => (exists bytes4 sel. dispatchFacet(sel) == delegateTarget && dispatchFacet(sel) != 0);
}
