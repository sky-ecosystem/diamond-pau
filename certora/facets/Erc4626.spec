// Erc4626.spec
//
// ERC4626Facet: the generic facet rules plus rules for each external function. The proxy call is
// summarised: the summary decodes the calldata the facet hands to the proxy, so the rules check its
// target, function and arguments exactly, and lets the call revert or return an arbitrary answer.
// Token balances are a ghost indexed by the number of proxy calls made so far, so every proxy call
// may move any balance arbitrarily, which covers every vault and token behaviour, and lets the
// rules check that shares and assets are exactly the measured balance changes. Approvals made
// through ApproveLib reach the proxy like every other call, with arbitrary token answers, so both of
// its paths (direct, and reset-and-retry) are covered. That the proxy then forwards the calldata
// unchanged is proven by the ALMProxy spec (doCall).

import "FacetBase.spec";

using CallDecoder as decoder;

// --- Methods block ---

methods {
    function EXCHANGE_RATE_PRECISION()                external returns (uint256) envfree;
    function getMaxExchangeRate(address)              external returns (uint256) envfree;
    function getDepositRateLimitKey(address, address) external returns (bytes32) envfree;
    function getWithdrawRateLimitKey(address)         external returns (bytes32) envfree;

    function decoder.decodeCall(bytes)       external returns (uint256, bytes4, uint256, uint256, uint256) envfree;
    function decoder.isAcceptedAnswer(bytes) external returns (bool)                                      envfree;
    function decoder.isInvalidBool(bytes)    external returns (bool)                                      envfree;

    function _.doCall(address target, bytes data) external => cvlDoCall(target, data) expect bytes;

    // Vault and token reads (static calls)
    function _.asset()                    external => assetOf(calledContract)                      expect address;
    function _.balanceOf(address account) external => balanceAt(calledContract, account, doCalls) expect uint256;
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

override definition OWN_NAMESPACE() returns uint8 = NAMESPACE_ERC4626Facet_v1();

definition APPROVE_SELECTOR()  returns bytes4 = to_bytes4(0x095ea7b3);  // approve(address,uint256)
definition DEPOSIT_SELECTOR()  returns bytes4 = to_bytes4(0x6e553f65);  // deposit(uint256,address)
definition WITHDRAW_SELECTOR() returns bytes4 = to_bytes4(0xb460af94);  // withdraw(uint256,address,address)
definition REDEEM_SELECTOR()   returns bytes4 = to_bytes4(0xba087652);  // redeem(uint256,address,address)

definition PRECISION() returns mathint = 10 ^ 36;

// sky.pau.storage.ERC4626Facet.v1
definition maxExchangeRateOf(address token) returns uint256 =
    currentContract.ext_sky_pau_storage_ERC4626Facet_v1.maxExchangeRates[token];

// _getExchangeRate(shares, assets): 0 for zero assets; otherwise it reverts for zero shares or when
// PRECISION * assets overflows, and is floor(PRECISION * assets / shares). Stated without division.
definition exchangeRateReverts(mathint shares, mathint assets) returns bool =
    assets != 0 && (shares == 0 || PRECISION() * assets > max_uint256);

definition isExchangeRate(mathint shares, mathint assets, mathint rate) returns bool =
    assets == 0 ? rate == 0
                : shares > 0 && rate * shares <= PRECISION() * assets && PRECISION() * assets < (rate + 1) * shares;

// _getExchangeRate(shares, assets) <= maxRate, when it does not revert
definition exchangeRateWithin(mathint shares, mathint assets, mathint maxRate) returns bool =
    assets == 0 || (shares > 0 && PRECISION() * assets < (maxRate + 1) * shares);

// --- Summaries ---

persistent ghost assetOf(address) returns address;

// balanceAt(token, account, n): the balance after n proxy calls
persistent ghost balanceAt(address, address, mathint) returns uint256;

// Every call the facet asks the proxy to make, in order: target, calldata length, selector, first
// three argument words, the rate limit decreases made before it, whether it reverted, and how its
// answer reads to ApproveLib.
persistent ghost mathint doCalls;
persistent ghost mapping(mathint => address) callTarget;
persistent ghost mapping(mathint => uint256) callLength;
persistent ghost mapping(mathint => bytes4)  callSelector;
persistent ghost mapping(mathint => uint256) callWord0;
persistent ghost mapping(mathint => uint256) callWord1;
persistent ghost mapping(mathint => uint256) callWord2;
persistent ghost mapping(mathint => mathint) callDecreasesBefore;
persistent ghost mapping(mathint => bool)    callReverted;
persistent ghost mapping(mathint => bool)    callAnswerAccepted;
persistent ghost mapping(mathint => bool)    callAnswerInvalid;

// Any proxy call either reverts, or returns an arbitrary answer. Balances read after it are those
// of the next index of balanceAt, so they are arbitrary too.
function cvlDoCall(address target, bytes data) returns bytes {
    mathint i = doCalls;
    doCalls = doCalls + 1;

    uint256 length;
    bytes4  selector;
    uint256 word0;
    uint256 word1;
    uint256 word2;
    length, selector, word0, word1, word2 = decoder.decodeCall(data);

    callTarget[i]          = target;
    callLength[i]          = length;
    callSelector[i]        = selector;
    callWord0[i]           = word0;
    callWord1[i]           = word1;
    callWord2[i]           = word2;
    callDecreasesBefore[i] = rateLimitDecreases;

    bool reverts;
    callReverted[i] = reverts;
    if (reverts) {
        revert("proxy call failed");
    }

    bytes answer;
    callAnswerAccepted[i] = decoder.isAcceptedAnswer(answer);
    callAnswerInvalid[i]  = decoder.isInvalidBool(answer);

    return answer;
}

// Call i was made; it reverted; it returned an answer ApproveLib accepts; it returned a word that
// does not decode as a bool
definition made(mathint i)          returns bool = doCalls > i;
definition failed(mathint i)        returns bool = made(i) && callReverted[i];
definition accepted(mathint i)      returns bool = made(i) && !callReverted[i] && callAnswerAccepted[i];
definition invalidAnswer(mathint i) returns bool = made(i) && !callReverted[i] && callAnswerInvalid[i];

// A proxy call is `token.approve(spender, amount)`
definition isApproveCall(mathint i, address token, address spender, uint256 amount) returns bool =
    callTarget[i]   == token &&
    callLength[i]   == 68 &&
    callSelector[i] == APPROVE_SELECTOR() &&
    callWord0[i]    == to_mathint(spender) &&
    callWord1[i]    == amount;

// ApproveLib.approve whose first call is call k reverts. That call goes through a low-level call,
// so its revert is caught. If its answer is accepted, the approval is that one call; otherwise
// approve(0) and the approve again follow, and the last answer must be accepted. An answer that
// does not decode as a bool reverts at once.
definition approvalReverts(mathint k) returns bool =
    invalidAnswer(k) ||
    (made(k) && !accepted(k) && !invalidAnswer(k) &&
        (failed(k + 1) || failed(k + 2) || (made(k + 2) && !accepted(k + 2))));

function setupRecorders() {
    require rateLimitDecreases == 0 && rateLimitIncreases == 0;
    require doCalls == 0;
}

// --- Storage Affected Rule ---

rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    address anyToken;

    uint256 maxExchangeRateBefore = maxExchangeRateOf(anyToken);

    f(e, args);

    assert maxExchangeRateOf(anyToken) != maxExchangeRateBefore =>
        f.selector == sig:setMaxExchangeRate(address, uint256, uint256).selector;
}

// --- External Calls Affected Rule ---

// Only the three allocator actions reach outside the facet. A function added later that calls out
// fails this rule until it is listed here.
rule externalCallsAffected(method f) filtered { f -> !f.isView } {
    env e;
    calldataarg args;

    require facetCalls == 0;

    f(e, args);

    assert facetCalls > 0 =>
        f.selector == sig:deposit(address, uint256, uint256).selector ||
        f.selector == sig:withdraw(address, uint256, uint256).selector ||
        f.selector == sig:redeem(address, uint256, uint256).selector;
}

// --- View function correctness ---

rule constants() {
    assert EXCHANGE_RATE_PRECISION() == PRECISION();
}

rule getMaxExchangeRate_correctness(address token) {
    assert getMaxExchangeRate(token) == maxExchangeRateOf(token);
}

// Each vault (and asset, for deposits) has its own limit, and deposits and withdrawals are limited
// separately
rule rateLimitKeys_distinct(address token1, address asset1, address token2, address asset2) {
    assert token1 != token2 || asset1 != asset2 =>
        getDepositRateLimitKey(token1, asset1) != getDepositRateLimitKey(token2, asset2);
    assert token1 != token2 => getWithdrawRateLimitKey(token1) != getWithdrawRateLimitKey(token2);
    assert getDepositRateLimitKey(token1, asset1) != getWithdrawRateLimitKey(token2);
}

// --- Admin functions: setMaxExchangeRate ---

// Stores the exchange rate of maxExpectedAssets per shares for the token, and nothing else
rule setMaxExchangeRate(address token, uint256 shares, uint256 maxExpectedAssets) {
    env e;

    address otherToken;
    require otherToken != token;

    uint256 otherMaxExchangeRateBefore = maxExchangeRateOf(otherToken);

    setMaxExchangeRate(e, token, shares, maxExpectedAssets);

    assert isExchangeRate(shares, maxExpectedAssets, maxExchangeRateOf(token));
    assert maxExchangeRateOf(otherToken) == otherMaxExchangeRateBefore;
}

rule setMaxExchangeRate_revert(address token, uint256 shares, uint256 maxExpectedAssets) {
    env e;

    uint256 status  = status();
    bool senderIsAdmin = isAdmin(e.msg.sender);

    setMaxExchangeRate@withrevert(e, token, shares, maxExpectedAssets);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAdmin;
    bool revert4 = token == 0;
    bool revert5 = exchangeRateReverts(shares, maxExpectedAssets);

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5;
}

// --- Allocator functions: deposit ---

// Charges the deposit limit of (token, asset) with `amount` before any proxy call, approves the
// asset to the vault for `amount`, deposits `amount` for the proxy, and resets the approval. The
// shares returned are the proxy's measured share balance change over the deposit call: at least
// minSharesOut, and at an exchange rate within the configured maximum.
//
// Each approval is one call, or three when the token's first answer is rejected, so the deposit
// call is call 1 or 3 and the run makes 3, 5 or 7 calls. Every one is checked at its index.
rule deposit(address token, uint256 amount, uint256 minSharesOut) {
    env e;

    setupRecorders();

    address proxy           = proxySlot();
    address asset           = assetOf(token);
    uint256 maxExchangeRate = maxExchangeRateOf(token);

    uint256 shares = deposit(e, token, amount, minSharesOut);

    mathint depositIndex = accepted(0) ? 1 : 3;
    mathint resetIndex   = depositIndex + 1;

    // Rate limit: charged once with `amount`, before any proxy call
    assert rateLimitDecreases     == 1;
    assert rateLimitIncreases     == 0;
    assert lastDecreasedKey       == getDepositRateLimitKey(token, asset);
    assert lastDecreasedAmount    == amount;
    assert callDecreasesBefore[0] == 1;

    // Approval of the asset to the vault for `amount`: call 0, followed by approve(0) and the
    // approve again when its answer is rejected
    assert isApproveCall(0, asset, token, amount);
    assert !accepted(0) => isApproveCall(1, asset, token, 0) && isApproveCall(2, asset, token, amount);

    // Then token.deposit(amount, proxy)
    assert callTarget[depositIndex]   == token;
    assert callLength[depositIndex]   == 68;
    assert callSelector[depositIndex] == DEPOSIT_SELECTOR();
    assert callWord0[depositIndex]    == amount;
    assert callWord1[depositIndex]    == to_mathint(proxy);

    // Then the approval reset to zero: call `resetIndex`, followed by two more approve(0) when its
    // answer is rejected, and nothing else
    assert isApproveCall(resetIndex, asset, token, 0);
    assert !accepted(resetIndex) =>
        isApproveCall(resetIndex + 1, asset, token, 0) && isApproveCall(resetIndex + 2, asset, token, 0);
    assert doCalls == (accepted(resetIndex) ? resetIndex + 1 : resetIndex + 3);

    // Shares: the measured balance change over the deposit call, within both bounds
    assert shares == balanceAt(token, proxy, resetIndex) - balanceAt(token, proxy, depositIndex);
    assert shares >= minSharesOut;
    assert exchangeRateWithin(shares, amount, maxExchangeRate);
}

// The two directions are stated separately. The first call of each approval is a low-level call,
// and when it reverts, ApproveLib copies the revert data into memory. The prover does not bound
// that data's size, so it can leave the free-memory pointer next to the 2^64 limit, and the next
// allocation then reverts. On chain, that much memory runs out of gas first. Reverts after such a
// caught failure are therefore allowed in the second direction.
rule deposit_revert(address token, uint256 amount, uint256 minSharesOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    uint256 maxExchangeRate   = maxExchangeRateOf(token);
    uint256 status            = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    deposit@withrevert(e, token, amount, minSharesOut);

    bool reverted = lastReverted;

    mathint depositIndex = accepted(0) ? 1 : 3;
    mathint resetIndex   = depositIndex + 1;
    bool    deposited    = made(depositIndex) && !callReverted[depositIndex];
    mathint shares       = balanceAt(token, proxy, resetIndex) - balanceAt(token, proxy, depositIndex);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = approvalReverts(0);
    bool revert5 = failed(depositIndex);
    bool revert6 = deposited && shares < 0;
    bool revert7 = deposited && shares < minSharesOut;
    bool revert8 = deposited && shares >= 0 &&
                   (exchangeRateReverts(shares, amount) || !exchangeRateWithin(shares, amount, maxExchangeRate));
    bool revert9 = deposited && approvalReverts(resetIndex);

    bool caughtFailure = failed(0) || (deposited && failed(resetIndex));

    // Each of these makes the call revert
    assert revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 || revert9 => reverted;
    // And nothing else does, except running out of memory after a caught failure
    assert reverted => revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7 || revert8 || revert9 ||
                       caughtFailure;
}

// --- Allocator functions: withdraw ---

// Withdraws `amount` of the asset from the vault to the proxy, in one proxy call and no approval.
// The shares returned are the proxy's measured share balance decrease, at most maxSharesIn. The
// withdraw limit is charged, and the deposit limit replenished when configured, with the assets the
// proxy actually received, after the call.
rule withdraw(address token, uint256 amount, uint256 maxSharesIn) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address asset             = assetOf(token);
    bytes32 depositKey        = getDepositRateLimitKey(token, asset);
    bool    depositConfigured = rateLimitMaxAmount(depositKey) > 0;

    uint256 shares = withdraw(e, token, amount, maxSharesIn);

    mathint assets = balanceAt(asset, proxy, 1) - balanceAt(asset, proxy, 0);

    // Exactly one proxy call: token.withdraw(amount, proxy, proxy)
    assert doCalls == 1;
    assert callTarget[0]   == token;
    assert callLength[0]   == 100;
    assert callSelector[0] == WITHDRAW_SELECTOR();
    assert callWord0[0]    == amount;
    assert callWord1[0]    == to_mathint(proxy);
    assert callWord2[0]    == to_mathint(proxy);

    // Shares: the measured balance decrease, within the bound
    assert shares == balanceAt(token, proxy, 0) - balanceAt(token, proxy, 1);
    assert shares <= maxSharesIn;

    // Rate limits: after the call, with the assets received
    assert callDecreasesBefore[0] == 0;
    assert rateLimitDecreases     == 1;
    assert lastDecreasedKey       == getWithdrawRateLimitKey(token);
    assert lastDecreasedAmount    == assets;
    assert rateLimitIncreases     == (depositConfigured ? 1 : 0);
    assert depositConfigured => lastIncreasedKey == depositKey && lastIncreasedAmount == assets;
}

rule withdraw_revert(address token, uint256 amount, uint256 maxSharesIn) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address asset             = assetOf(token);
    uint256 status            = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    withdraw@withrevert(e, token, amount, maxSharesIn);

    bool    called = made(0) && !callReverted[0];
    mathint assets = balanceAt(asset, proxy, 1) - balanceAt(asset, proxy, 0);
    mathint shares = balanceAt(token, proxy, 0) - balanceAt(token, proxy, 1);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = failed(0);
    bool revert5 = called && assets < 0;
    bool revert6 = called && shares < 0;
    bool revert7 = called && shares > maxSharesIn;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6 || revert7;
}

// --- Allocator functions: redeem ---

// Redeems `shares` from the vault to the proxy, in one proxy call and no approval. The assets
// returned are the proxy's measured asset balance increase, at least minAssetsOut. The withdraw
// limit is charged, and the deposit limit replenished when configured, with those assets, after the
// call.
rule redeem(address token, uint256 shares, uint256 minAssetsOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address asset             = assetOf(token);
    bytes32 depositKey        = getDepositRateLimitKey(token, asset);
    bool    depositConfigured = rateLimitMaxAmount(depositKey) > 0;

    uint256 assets = redeem(e, token, shares, minAssetsOut);

    // Exactly one proxy call: token.redeem(shares, proxy, proxy)
    assert doCalls == 1;
    assert callTarget[0]   == token;
    assert callLength[0]   == 100;
    assert callSelector[0] == REDEEM_SELECTOR();
    assert callWord0[0]    == shares;
    assert callWord1[0]    == to_mathint(proxy);
    assert callWord2[0]    == to_mathint(proxy);

    // Assets: the measured balance increase, within the bound
    assert assets == balanceAt(asset, proxy, 1) - balanceAt(asset, proxy, 0);
    assert assets >= minAssetsOut;

    // Rate limits: after the call, with the assets received
    assert callDecreasesBefore[0] == 0;
    assert rateLimitDecreases     == 1;
    assert lastDecreasedKey       == getWithdrawRateLimitKey(token);
    assert lastDecreasedAmount    == assets;
    assert rateLimitIncreases     == (depositConfigured ? 1 : 0);
    assert depositConfigured => lastIncreasedKey == depositKey && lastIncreasedAmount == assets;
}

rule redeem_revert(address token, uint256 shares, uint256 minAssetsOut) {
    env e;

    setupRecorders();

    address proxy             = proxySlot();
    address asset             = assetOf(token);
    uint256 status            = status();
    bool    senderIsAllocator = isAllocator(e.msg.sender);

    redeem@withrevert(e, token, shares, minAssetsOut);

    bool    called = made(0) && !callReverted[0];
    mathint assets = balanceAt(asset, proxy, 1) - balanceAt(asset, proxy, 0);

    bool revert1 = e.msg.value > 0;
    bool revert2 = status == ENTERED();
    bool revert3 = !senderIsAllocator;
    bool revert4 = failed(0);
    bool revert5 = called && assets < 0;
    bool revert6 = called && assets < minAssetsOut;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4 || revert5 || revert6;
}
