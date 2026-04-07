# Diamond PAU — Audit Gap Analysis

**Date:** 2026-04-06
**Scope:** All 24 audit reports (v1.0.0 through v1.11.0) across Cantina, ChainSecurity, Certora, and Unvariant
**Baseline:** `origin/dev` + all 9 open PRs (#88, #91, #96, #97, #100, #102, #103, #105, #106) assumed merged
**Prepared by:** Sparky (Automated Security Auditor)

---

## Executive Summary

Across 24 audit reports from 4 auditing firms, **17 distinct non-resolved findings** remain outstanding after accounting for all fixes on `dev` and all open PRs. The majority are Low severity or Informational — there are **no outstanding Critical or High findings** and **one outstanding Medium** (from Unvariant, acknowledged by design).

| Severity | Outstanding | Addressed by Open PRs | Total Acknowledged |
|---|---|---|---|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 1 | 0 | 1 |
| Low | 9 | 1 | 10 |
| Informational | 15 | 2 | 17 |
| **Total** | **25** | **3** | **28** |

> Note: Many findings from earlier audits (v1.0.0–v1.9.0) were resolved during the v1.11.0 diamond refactor or fixed in subsequent versions. The counts above reflect only findings that remain unresolved in the effective codebase (dev + open PRs).

---

## Open PR Impact Summary

| PR | Title | Audit Findings Addressed |
|---|---|---|
| #102 | fix: Internal Audit | Zero-address validation across all contracts, dispatch→wiring refactor, selector clash protection, facet bytecode validation, enhanced events |
| #103 | feat: Facet events | Adds events to all facet operations — addresses CS-SKYDPAU-011 (events not librarificated), CS-SPRKALM-003 equivalent for diamond |
| #105 | feat: Add DAIUSDS ratelimit | Adds rate limiting to DAI↔USDS swaps — partially addresses CS-SKYDPAU-003 (Lack of Rate Limits) |
| #100 | feat: Facet storage version tags | Adds version strings to facets for upgrade safety |
| #97 | feat: Deploy scripts | Deploy scripts for factory, PAU, and facets |
| #96 | test: Close coverage gaps | Test coverage only |
| #106 | feat: WEETHModule tests | Test coverage only |
| #91 | Grove basin | New integration (Grove Basin) |
| #88 | refactor: Test Cleanup | Test refactoring only |

---

## Outstanding Findings

### MEDIUM SEVERITY

#### M-1: Uniswap V3 removeLiquidity can be executed at manipulated prices
- **Source:** Unvariant v1.11.0 (MEDIUM-03)
- **Status:** Acknowledged (by design)
- **Auditor:** Unvariant
- **Affected (legacy):** `UniswapV3Lib.sol` → **Affected (diamond):** `UniswapV3Facet` / `UniswapV3Utils`
- **Description:** `removeLiquidity()` only validates relayer-supplied min amounts against amounts actually collected — the check is self-referential. Unlike `swap()` and `addLiquidity()` which use TWAP-anchored protections, removals have no independent price reference. A sandwich attacker could extract value from Uniswap V3 positions during liquidity removal.
- **Team Response:** "The Grove team wants to prioritize removing liquidity quickly and without additional barriers over limits that may result in DOS vectors. A future review of the UniswapV3 integration may either adopt that pattern, or consider the tradeoffs."
- **Recommendation:** Consider adding TWAP-based validation for `removeLiquidity` min amounts, similar to `_getExpectedAmounts()` approach in `addLiquidity()`.
- **Risk:** A compromised or colluding relayer could sandwich liquidity removals. Mitigated by the freezer role's ability to remove compromised relayers.

---

### LOW SEVERITY

#### L-1: Centrifuge Deposit/Redemption Can Be DoSed by Cancellation
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-001)
- **Status:** Risk Accepted
- **Affected (diamond):** `CentrifugeFacet`
- **Description:** A compromised relayer can DoS new deposit/redemption requests by triggering cancellations. In Centrifuge, a pending cancellation blocks new requests of the same type.
- **Team Response:** Sky is aware of the risk. Mitigated by freezer removing compromised relayer.

#### L-2: Centrifuge Tranche Token Price May Change Between Request and Execution
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-002)
- **Status:** Risk Accepted
- **Affected (diamond):** `CentrifugeFacet` / `ERC7540Facet`
- **Description:** When requesting a Centrifuge redemption, the rate limit is decreased based on the current tranche token price. The actual withdrawable assets may differ when the request is executed, creating a discrepancy between rate limit accounting and actual exposure.

#### L-3: Lack of Rate Limits (LayerZero global + native token)
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-003)
- **Status:** Code Partially Corrected / Acknowledged
- **Affected (diamond):** `LayerZeroFacet`
- **Description:** Two sub-issues: (1) LayerZero lacks a global per-token rate limit, unlike CCTP which has per-destination + global limits — inconsistency. (2) Native tokens used for LayerZero fees are not rate limited, so a relayer colluding with an endpoint operator could drain native token balance.
- **Note:** PR #105 adds rate limiting to DAI↔USDS, but the LayerZero-specific inconsistencies remain.
- **Addressed by open PR:** Partially (#105 adds some rate limits, but not the LayerZero-specific ones)

#### L-4: LayerZero Dangling Approvals
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-004)
- **Status:** Code Partially Corrected / Acknowledged
- **Affected (diamond):** `LayerZeroFacet`
- **Description:** After `send()`, the OFT may have pulled less tokens than approved (LayerZero dust removal). Pending approvals remain, which could introduce corner cases if ZRO tokens are held and bridged — a dangling approval could allow lzTokenFee > 0 to be collected.

#### L-5: Maple Redemption Can Be DoSed
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-005)
- **Status:** Risk Accepted
- **Affected (diamond):** `MapleFacet`
- **Description:** A compromised relayer can DoS Maple redemptions in two ways: (1) trigger dust redemptions since each user can have at most 1 request, blocking legitimate ones; (2) consume the rate limit entirely since cancellation doesn't restore capacity. Mitigated by freezer role.

#### L-6: Over-reduced Limit in Maple Redemption
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-006)
- **Status:** Risk Accepted
- **Affected (diamond):** `MapleFacet`
- **Description:** `requestMapleRedemption()` reduces rate limit using `convertToAssets()` which ignores unrealized losses. Actual received tokens may be less, creating a discrepancy. Related to Certora v1.9.0 L-04.

#### L-7: Relayer Can DoS sUSDe Unstaking
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-007)
- **Status:** Risk Accepted
- **Affected (diamond):** `USDEFacet`
- **Description:** A malicious relayer can repeatedly trigger 1 wei cooldowns on sUSDe, extending the cooldown period and blocking legitimate unstaking. Mitigated by freezer role removing the malicious relayer.

#### L-8: Revoking Unused Approval (Ethena)
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-008)
- **Status:** Acknowledged
- **Affected (diamond):** `USDEFacet`
- **Description:** After the freezer removes a relayer, Ethena operations may still complete because the Ethena integration requires actions from external parties. Actual asset transfers to mint/redeem USDe can happen after the relayer is disabled, since approvals were already set.
- **Team Response:** Ethena is fully trusted.

#### L-9: Rate limit capacity not restored on Centrifuge/Maple cancellations
- **Source:** Unvariant v1.11.0 (LOW-08, LOW-10), Cantina v1.11.0 (I-1)
- **Status:** Acknowledged
- **Affected (diamond):** `CentrifugeFacet`, `MapleFacet`
- **Description:** When Centrifuge deposit/redeem requests or Maple redemptions are cancelled, the rate limit consumed by the original request is not restored. Assets return to ALMProxy but rate capacity is permanently consumed — only recovers via natural slope over time. Contrast with ERC4626/Aave which do restore capacity on withdrawal.
- **Team Response:** "The recommendation will likely be adopted in a subsequent update." (Unvariant) / "Intended business functionality." (Maple)

---

### INFORMATIONAL

#### I-1: Allowance for Ethena Minter May Not Be Consumed
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-013)
- **Status:** Acknowledged
- **Affected (diamond):** `USDEFacet`
- **Description:** Ethena allowances set by `prepareMint()`/`prepareBurn()` may not be fully consumed if delegated signers sign smaller orders, Ethena refuses to submit, or per-block limits are hit. Rate limit accounting tracks approved amounts, not actual consumed amounts.
- **Related:** Unvariant LOW-06 (Rate limit exhaustion in Ethena integration) — a relayer could repeatedly call prepare functions, draining rate limit without actual mints/burns.

#### I-2: Can Only Collect Uniswap V3 Position Fees When Removing Liquidity
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-014)
- **Status:** Acknowledged
- **Affected (diamond):** `UniswapV3Facet`
- **Description:** No separate `collect()` function exists — fees can only be collected during `removeLiquidity()` which requires removing non-zero liquidity. Contrast with Uniswap V4 which allows `decreasePosition(liquidityDecrease=0)` for fee-only collection.

#### I-3: Code Redundancy
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-009)
- **Status:** Partially Corrected / Acknowledged
- **Affected (diamond):** Various
- **Description:** Duplicated functions (RateLimitHelpers library vs free functions), duplicated interfaces (IERC20Like, IERC4626Like across contracts), inconsistent ApproveLib usage (some libraries use custom approval logic). Partially addressed by PR #102 (removed unused ApproveLib import).

#### I-4: CurveLib Rounding Error Amplification
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-010), Certora v1.9.0 (M-02), Cantina v1.11.0 (I-4)
- **Status:** Acknowledged
- **Affected (diamond):** `CurveFacet`
- **Description:** The current `minAmountOut` calculation performs three divisions, each introducing truncation. The previous implementation used multiplication-first ordering to minimize precision loss. The rounding error is amplified by consecutive multiplications. Team accepted the tradeoff for code readability.

#### I-5: Dust eETH Shares When Wrapping Into weETH
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-015)
- **Status:** Acknowledged
- **Affected (diamond):** `WEETHFacet`
- **Description:** Due to rounding in share↔amount conversions, not all eETH shares may be wrapped into weETH. Dust amounts of 1-2 shares can be left behind per wrapping operation.

#### I-6: Inconsistency Across Integrations
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-011)
- **Status:** Partially Corrected / Acknowledged
- **Affected (diamond):** Various facets
- **Description:** Multiple inconsistencies: (1) Some addresses not validated as non-zero before use (pendleRouter, merklDistributor, uniswapV3Router/PositionManager). (2) Inconsistent function argument syntax (named vs positional). (3) Inconsistent ApproveLib usage. (4) Inconsistent rate limit invocation patterns. (5) Not all external functions librarificated — some events still in controller. (6) Inconsistent interface imports. (7) Inconsistent constant naming. (8) Inconsistent address passing (some hardcoded, some parameterized).
- **Note:** PR #102 addresses sub-issue (1) with zero-address checks. PR #103 addresses sub-issue (5) by adding events to all facets.
- **Addressed by open PRs:** Partially (#102, #103)

#### I-7: Missing Validation of Pendle Market V3
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-017)
- **Status:** Acknowledged
- **Affected (diamond):** `PendleFacet`
- **Description:** Rate limit checks validate that the Pendle market contract is whitelisted by admin, but don't verify it was deployed by `PendleMarketFactoryV3` using `isValidMarket()`. Team says validation is done in spell tests during onboarding.

#### I-8: Per-Pool maxSlippage Instead of Per-Operation
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-018)
- **Status:** Acknowledged
- **Affected (diamond):** `CurveFacet`, `UniswapV3Facet`
- **Description:** A single `maxSlippage` value is defined per pool and used for all operations (swap, addLiquidity, removeLiquidity). Different operations may warrant different slippage tolerances (e.g., removeLiquidity with impermanent loss vs swap). Team accepted since they operate primarily in stablecoin-stablecoin pools.

#### I-9: Use UniversalRouter Instead of SwapRouter02
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-019)
- **Status:** Acknowledged
- **Affected (diamond):** `UniswapV3Facet`
- **Description:** Sky uses Uniswap's legacy SwapRouter02 instead of the recommended UniversalRouter. The library already calculates balance deltas which would make the switch possible. SwapRouter02 is archived by Uniswap.
- **Related:** Unvariant LOW-09 — the SwapRouter02 interface lacks a `deadline` field, and the library doesn't wrap calls in `multicall(deadline, ...)`, removing deadline protection from swaps.

#### I-10: Withdraw From Aave Can Be Blocked By LTV=0 Asset
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-020)
- **Status:** Acknowledged
- **Affected (diamond):** `AaveFacet`
- **Description:** An attacker can supply dust aTokens on behalf of ALMProxy for an asset about to have LTV set to 0 on Aave. After the parameter change, ALMProxy would be unable to withdraw other collateral-enabled assets. Mitigated: relayer can withdraw the LTV=0 asset (rate limit will be added for this case).

#### I-11: setOTCRechargeRate May Flip OTC Swap Status
- **Source:** ChainSecurity v1.11.0 (CS-SKYDPAU-022)
- **Status:** Acknowledged
- **Affected (diamond):** `OTCFacet`
- **Description:** Changing the recharge rate during an active swap retroactively applies the new rate to the entire elapsed time, potentially causing `isOtcSwapReady()` to flip immediately.

#### I-12: Overloaded maxSlippages Weakens Access Control (Carried from v1.8.0)
- **Source:** Certora v1.8.0 (L-01)
- **Status:** Acknowledged
- **Affected (diamond):** `FacetBase` / shared slippage storage
- **Description:** The `maxSlippages` mapping is shared across multiple asset types (Curve pools, ERC4626 vaults, Aave aTokens, OTC exchanges). This overloading weakens access control — the same slippage value controls different risk profiles. Team acknowledged and planned refactoring for v2 (diamond architecture may partially address this if each facet has separate storage).

#### I-13: Insufficient Slippage Protection in UniswapV4 Functions
- **Source:** Certora v1.9.0 (L-06)
- **Status:** Acknowledged
- **Affected (diamond):** `UniswapV4Facet`
- **Description:** The `maxSlippage` setting clamps `amountOutMin` relative to a hardcoded 1:1 price assumption. Not accurate if pools contain depegged assets or non-stable pairs are supported in the future. Should use TWAP-based slippage instead.

#### I-14: Uniswap V3 and V4 Asymmetries
- **Source:** Cantina v1.11.0 (L-1)
- **Status:** Acknowledged (partially fixed in v1.11.0 PR 48)
- **Affected (diamond):** `UniswapV3Facet`, `UniswapV4Facet`
- **Description:** Multiple asymmetries between V3 and V4 integrations: (1) V3 excludes fees from withdraw accounting post-fix, V4 includes them. (2) V4 uses one normalized limit per pool, V3 uses two token-side limits. (3) V4 allows fee-only collection via zero liquidity decrease, V3 blocks it. (4) V3 swap limit uses observed post-swap input, V4 uses requested pre-swap input.

#### I-15: Excess ETH Refund from Centrifuge Goes to ALMProxy, Not Relayer
- **Source:** Unvariant v1.11.0 (LOW-07)
- **Status:** Acknowledged
- **Affected (diamond):** `CentrifugeFacet`
- **Description:** When transferring Centrifuge shares cross-chain, excess ETH paid by the relayer for messaging gas is refunded to ALMProxy instead of the relayer, because the call goes through ALMProxy as `msg.sender`. Team plans to use the 8-parameter `crosschainTransferShares()` function in a subsequent update.

---

## Findings Addressed by dev + Open PRs (Already Resolved)

The following findings from v1.11.0 audits were resolved either on `dev` or will be resolved when open PRs merge:

| Finding | Auditor | Fixed By |
|---|---|---|
| UniswapV3 removeLiquidity DoS by fee accrual | Cantina M-1, Unvariant MEDIUM-01 | v1.11.0 PR 38 (on dev) |
| Diamond-pau changes affecting Grove (ABI drift) | Cantina M-2 | Partially on dev |
| CCTPLib hardcoded MAX_FEE = 0 | Cantina L-2, Unvariant LOW-01 | v1.11.0 PR 41 (on dev) |
| LayerZero no refund for overpaid nativeFee | Cantina I-5 | v1.11.0 PR 43 (on dev) |
| Centrifuge manager() → baseManager() | Unvariant MEDIUM-02 | v1.11.0 fix commit (on dev) |
| Missing maxSlippage check in removeLiquidity | Unvariant LOW-03 | v1.11.0 fix commit (on dev) |
| Cancel/claim blocked when maxAmount=0 | Unvariant LOW-04 | v1.11.0 fix commit (on dev) |
| Small burnLimit gas intensity | Unvariant LOW-05 | v1.11.0 fix commit (on dev) |
| Missing zero burnLimit validation | Unvariant LOW-02 | v1.11.0 fix commit (on dev) |
| Typos (IERC20ike, ApprobeLib, cancelation) | ChainSecurity CS-SKYDPAU-012, Cantina I-6 items 1-3 | v1.11.0 PR 40 + PR #102 |
| msg.value validation in LayerZero | ChainSecurity CS-SKYDPAU-021 | v1.11.0 (on dev) |
| Zero-address checks across all contracts | PR #102 | Open PR |
| Dispatch→wiring refactor with selector clash protection | PR #102 | Open PR |
| Facet bytecode validation in PAUFactory | PR #102 | Open PR |
| Events on all facet operations | PR #103 | Open PR |
| DAIUSDS rate limiting | PR #105 | Open PR |
| Facet storage version tags | PR #100 | Open PR |
| wstETH rate limiting on claimWithdrawal | dev commit 5332c15 | On dev |

---

## Earlier Audit Findings (v1.0.0–v1.10.0) — Status in Diamond Architecture

Many findings from earlier audits targeted the monolithic `MainnetController`/`ForeignController` architecture. The v1.11.0 diamond refactor reorganized the codebase significantly. Below summarizes the disposition of earlier acknowledged findings:

### Fully Resolved by Diamond Refactor
- **Bytecode size limits** — Diamond proxy pattern eliminates this constraint entirely
- **Constructor parameter validation** — PR #102 adds comprehensive zero-address checks
- **Event emissions on state changes** — PR #103 adds events to all facets
- **Inconsistent AccessControl** (Certora v1.8.0 I-01) — Diamond uses centralized `AccessControls` contract

### Carried Forward (Still Relevant)
All findings listed in the "Outstanding Findings" section above apply to the diamond architecture. Key inherited findings:
- CurveLib rounding (originally flagged in v1.9.0, still present in diamond libs)
- Overloaded maxSlippages (originally v1.8.0, still present as shared storage)
- Rate limit inconsistencies across integrations (originally v1.8.0+, partially improved)
- Ethena trust assumptions (originally v1.1.0+, unchanged)
- Maple/Centrifuge cancellation rate limit gaps (originally v1.8.0+, unchanged)

### No Longer Applicable
- **v1.0.0 ChainSecurity findings** — All 7 findings were resolved in v1.0.0 itself
- **v1.0.0-beta Cantina findings** — All resolved except I-5 (redundant mintRecipient check, intentionally kept)
- **Findings specific to removed code** (e.g., old `freeze()` function, removed in diamond)

---

## Recommendations

### Priority 1 — Should Address Before Deployment
1. **M-1 (UniV3 removeLiquidity at manipulated prices):** Even though acknowledged, this is the highest-severity outstanding issue. Consider implementing TWAP-based validation similar to `addLiquidity()`, or at minimum document the relayer trust assumption explicitly in the facet's NatSpec.

### Priority 2 — Should Address in Next Release
2. **L-9 (Rate limit restoration on cancellations):** The Centrifuge and Maple cancellation flows permanently consume rate limit capacity. This creates operational friction and could require admin intervention. Restoring capacity on claim-cancel operations would make rate limit accounting consistent with ERC4626/Aave flows.
3. **I-9/Unvariant LOW-09 (SwapRouter02 → UniversalRouter + deadline):** The legacy router lacks deadline protection on swaps. Adding deadline support would close this gap and future-proof the integration.
4. **I-2 (Uniswap V3 fee-only collection):** Adding a `collectFees()` function would eliminate the need to remove liquidity just to collect fees.

### Priority 3 — Address When Convenient
5. **I-4 (CurveLib rounding):** Restore multiplication-first ordering for the minAmountOut bound.
6. **I-6 (Inconsistency cleanup):** Continue the cleanup started in PRs #102 and #103.
7. **I-12 (Per-operation maxSlippage):** Consider per-operation slippage in the diamond's per-facet storage.
8. **Unvariant LOW-11 (wstETH hint-based claim):** Use `claimWithdrawalsTo()` with pre-computed hints to avoid out-of-gas scenarios.

---

## Methodology

1. Extracted text from all 24 audit PDFs (v1.0.0 through v1.11.0) across Cantina, ChainSecurity, Certora, and Unvariant
2. Catalogued every finding and its resolution status
3. Analyzed the `dev` branch (43 commits ahead of v1.11.0 tag) for fixes already landed
4. Analyzed all 9 open PR diffs for fixes pending merge
5. Cross-referenced each non-resolved finding against the combined effective codebase
6. Mapped legacy contract references to diamond facet architecture
7. Deduplicated findings flagged by multiple auditors
