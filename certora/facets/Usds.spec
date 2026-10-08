// Usds.spec
//
// USDSFacet: the generic facet rules plus rules for each external function. The proxy calls are
// summarised: the summary decodes the calldata the facet hands to the proxy, so the rules check
// each call's target, function and arguments exactly, and lets each call revert or not. That the
// proxy then forwards this calldata unchanged is proven by the ALMProxy spec (doCall).

import "FacetBase.spec";

using CallDecoder as decoder;

// --- Methods block ---

methods {
    function usds()             external returns (address) envfree;
    function vault()            external returns (address) envfree;
    function mintRateLimitKey() external returns (bytes32) envfree;
    function burnRateLimitKey() external returns (bytes32) envfree;

    function decoder.decodeCall(bytes) external returns (uint256, bytes4, uint256, uint256, uint256) envfree;

    function _.doCall(address target, bytes data) external => cvlDoCall(target, data) expect bytes;

    // The vault's buffer, read by the facet with a static call: a pure function of the vault
    function _.buffer() external => bufferOf(calledContract) expect address;
}

// --- Generic rules ---

use rule roleGated;
use rule adminIsConfigurationOnly;
use rule rateLimitCallsAreFacetCalls;
use rule allocatorRequiresRateLimit;
use rule noForbiddenCalls;
use rule noProxyDelegateCalls;
use rule externalCallsOnlyToProxyAndRateLimits;
use rule reentrancyGuarded;
use rule sharedStorageUntouched;

// --- Definitions ---

definition DRAW_SELECTOR()          returns bytes4 = to_bytes4(0x3b304147);  // draw(uint256)
definition WIPE_SELECTOR()          returns bytes4 = to_bytes4(0xb38a1620);  // wipe(uint256)
definition TRANSFER_SELECTOR()      returns bytes4 = to_bytes4(0xa9059cbb);  // transfer(address,uint256)
definition TRANSFER_FROM_SELECTOR() returns bytes4 = to_bytes4(0x23b872dd);  // transferFrom(address,address,uint256)

// sky.pau.storage.USDSFacet.v1
definition vaultSlot() returns address = currentContract.ext_sky_pau_storage_USDSFacet_v1.vault;

// --- Proxy call summary ---

persistent ghost bufferOf(address) returns address;

// Every call the facet asks the proxy to make, in order: target, calldata length, selector and the
// first three argument words, and whether the rate limit had been consumed by then
persistent ghost mathint doCalls;
persistent ghost mapping(uint256 => address) callTarget;
persistent ghost mapping(uint256 => uint256) callLength;
persistent ghost mapping(uint256 => bytes4)  callSelector;
persistent ghost mapping(uint256 => uint256) callWord0;
persistent ghost mapping(uint256 => uint256) callWord1;
persistent ghost mapping(uint256 => uint256) callWord2;
persistent ghost bool anyCallBeforeDecrease;
persistent ghost bool anyCallReverted;

// The proxy call either reverts (the forwarded call failed) or returns an arbitrary answer, which
// the facet ignores
function cvlDoCall(address target, bytes data) returns bytes {
    uint256 i = require_uint256(doCalls);
    doCalls = doCalls + 1;

    uint256 length;
    bytes4  selector;
    uint256 word0;
    uint256 word1;
    uint256 word2;
    length, selector, word0, word1, word2 = decoder.decodeCall(data);

    callTarget[i]   = target;
    callLength[i]   = length;
    callSelector[i] = selector;
    callWord0[i]    = word0;
    callWord1[i]    = word1;
    callWord2[i]    = word2;

    if (rateLimitDecreases == 0) {
        anyCallBeforeDecrease = true;
    }

    bool reverts;
    if (reverts) {
        anyCallReverted = true;
        revert("proxy call failed");
    }

    bytes answer;
    return answer;
}

function setupRecorders() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require doCalls == 0 && !anyCallBeforeDecrease && !anyCallReverted;
}

// --- Storage Affected Rule ---

rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    address vaultBefore = vaultSlot();

    f(e, args);

    assert vaultSlot() != vaultBefore => f.selector == sig:setVault(address).selector;
}

// --- External Calls Affected Rule ---

// Only mint and burn reach outside the facet. FacetBase proves the facet never delegatecalls,
// callcodes or deploys, so a CALL is its only way out. A function added later that calls out fails
// this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 =>
        f.selector == sig:mint(uint256).selector ||
        f.selector == sig:burn(uint256).selector;
}

// --- View function correctness ---

rule vault_correctness() {
    assert vault() == vaultSlot();
}

// Minting and burning are limited separately
rule rateLimitKeys_distinct() {
    assert mintRateLimitKey() != burnRateLimitKey();
}

// --- Admin functions: setVault ---

rule setVault(address vault_) {
    env e;

    setVault(e, vault_);

    assert vaultSlot() == vault_;
}

rule setVault_revert(address vault_) {
    env e;

    uint256 statusBefore  = status();
    bool    senderIsAdmin = isAdmin(e.msg.sender);

    setVault@withrevert(e, vault_);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = vault_ == 0;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4;
}

// --- Allocator functions: mint ---

// Draws `usdsAmount` from the vault into its buffer, then pulls it from the buffer to the proxy.
// The return value of transferFrom is not checked: the facet relies on USDS reverting on failure.
rule mint(uint256 usdsAmount) {
    env e;

    setupRecorders();

    address vault_  = vaultSlot();
    address proxy   = proxySlot();
    address buffer_ = bufferOf(vault_);

    mint(e, usdsAmount);

    // Rate limit: the mint limit is decreased once by the amount, and nothing is increased
    assert rateLimitDecreases  == 1;
    assert rateLimitIncreases  == 0;
    assert lastDecreasedKey    == mintRateLimitKey();
    assert lastDecreasedAmount == usdsAmount;

    // Exactly two proxy calls, both after the rate limit was consumed
    assert doCalls == 2;
    assert !anyCallBeforeDecrease;

    // 1. vault.draw(usdsAmount)
    assert callTarget[0]   == vault_;
    assert callLength[0]   == 36;
    assert callSelector[0] == DRAW_SELECTOR();
    assert callWord0[0]    == usdsAmount;

    // 2. usds.transferFrom(buffer, proxy, usdsAmount)
    assert callTarget[1]   == usds();
    assert callLength[1]   == 100;
    assert callSelector[1] == TRANSFER_FROM_SELECTOR();
    assert callWord0[1]    == to_mathint(buffer_);
    assert callWord1[1]    == to_mathint(proxy);
    assert callWord2[1]    == usdsAmount;
}

rule mint_revert(uint256 usdsAmount) {
    env e;

    setupRecorders();

    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    mint@withrevert(e, usdsAmount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = anyCallReverted;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4;
}

// --- Allocator functions: burn ---

// Sends `usdsAmount` from the proxy to the vault's buffer, then wipes it from the buffer. The burn
// limit is consumed, and the mint limit is replenished if it is configured.
rule burn(uint256 usdsAmount) {
    env e;

    setupRecorders();

    address vault_     = vaultSlot();
    address buffer_    = bufferOf(vault_);
    bool    mintLimited = rateLimitMaxAmount(mintRateLimitKey()) > 0;

    burn(e, usdsAmount);

    // Rate limits: the burn limit is decreased once by the amount; the mint limit is increased
    // by the amount exactly when it exists
    assert rateLimitDecreases  == 1;
    assert lastDecreasedKey    == burnRateLimitKey();
    assert lastDecreasedAmount == usdsAmount;
    assert mintLimited  => rateLimitIncreases == 1;
    assert mintLimited  => lastIncreasedKey == mintRateLimitKey() && lastIncreasedAmount == usdsAmount;
    assert !mintLimited => rateLimitIncreases == 0;

    // Exactly two proxy calls, both after the rate limit was consumed
    assert doCalls == 2;
    assert !anyCallBeforeDecrease;

    // 1. usds.transfer(buffer, usdsAmount)
    assert callTarget[0]   == usds();
    assert callLength[0]   == 68;
    assert callSelector[0] == TRANSFER_SELECTOR();
    assert callWord0[0]    == to_mathint(buffer_);
    assert callWord1[0]    == usdsAmount;

    // 2. vault.wipe(usdsAmount)
    assert callTarget[1]   == vault_;
    assert callLength[1]   == 36;
    assert callSelector[1] == WIPE_SELECTOR();
    assert callWord0[1]    == usdsAmount;
}

rule burn_revert(uint256 usdsAmount) {
    env e;

    setupRecorders();

    uint256 statusBefore      = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    burn@withrevert(e, usdsAmount);

    bool revert1 = e.msg.value > 0;
    bool revert2 = statusBefore == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = anyCallReverted;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4;
}
