# Diamond PAU Refactor — Functional Equivalence Audit Report

**Date:** 2026-03-30
**Auditor:** Sparky (Automated Security Auditor)
**Scope:** Functional equivalence review of `diamond-pau` refactor from monolithic `MainnetController` (v1.11.0) to diamond-style `Controller` + facets (branch `refactor/dev-1516-renaming`)

---

## Executive Summary

The refactor successfully moves from a monolithic controller with library calls to a diamond-style proxy dispatching to facets. The core business logic is **functionally equivalent** across all 25 facets, with a small number of intentional improvements and findings documented below.

**Overall Assessment: PASS with findings**

- **0 Critical** findings
- **1 Medium** finding (UniswapV3Facet missing zero-address check on setMaxSlippage)
- **2 Low** findings
- **4 Informational** notes

---

## Phase 1: Dispatch and Interface Equivalence

### 1.1 Controller Fallback Mechanism

**PASS** — The `Controller.fallback()` correctly:
1. Looks up `dispatches[msg.sig]` to find `(facet, delegateSelector)`
2. Replaces the incoming selector with the delegate selector
3. `delegatecall`s the facet with `abi.encodePacked(delegateSelector, msg.data[4:])`
4. Forwards return data or reverts via assembly

The selector replacement is correct — `msg.data[4:]` strips the 4-byte call selector and prepends the delegate selector. This allows the external-facing selector to differ from the internal facet function selector (e.g., for name disambiguation).

### 1.2 setDispatch Access Control

**PASS** — `setDispatch` requires `DEFAULT_ADMIN_ROLE` via the `AccessControls` contract. Only admin can wire dispatch mappings.

### 1.3 receive() Function

**PASS** — `Controller` has `receive() external payable {}` to accept ETH, matching the old architecture where `MainnetController` could receive ETH via the proxy.

### 1.4 Function Signature Mapping

**PASS** — All 80+ functions from `MainnetController` and `ForeignController` have corresponding facet functions. Function names have been simplified (e.g., `depositAave` → `AaveFacet.deposit`, `swapUniswapV3` → `UniswapV3Facet.swap`) but the dispatch mapping allows the external selector to remain unchanged.

### 1.5 Overloaded Functions (CCTP)

**PASS** — The old `MainnetController` had two `transferUSDCToCCTP` overloads (with/without maxFee). The new `CCTPFacet` splits these into `transfer` and `transferWithFee`, which can be mapped to the same external selectors via dispatch.

---

## Phase 2: Access Control Equivalence

### 2.1 Access Control Architecture

**PASS** — The old system used OZ `AccessControlEnumerable` directly on `MainnetController`. The new system extracts access control to a separate `AccessControls` contract that inherits `AccessControlEnumerable`.

- `FacetBase.onlyRole` modifier calls `IAccessControls(accessControls).hasRole(role, msg.sender)`
- `accessControls` is read from `ControllerSharedStorage` (ERC-7201 namespaced)
- The `AccessControls` contract preserves `FREEZER_ROLE`, `RELAYER_ROLE`, and `DEFAULT_ADMIN_ROLE`

### 2.2 Role Assignments Per Function

**PASS** — All admin functions use `onlyRole(DEFAULT_ADMIN_ROLE)`, all relayer functions use `onlyRole(RELAYER_ROLE)`. This matches the production code.

Verified for all facets:
- Admin setters: `setMaxSlippage` (5 facets), `setMaxFeeCap`, `setMintRecipient`, `setRecipient` (LayerZero, Centrifuge), `setMaxTickDelta`, tick bound setters, `setTWAPSecondsAgo`, `setTickLimits` (V4), `setMaxExchangeRate`, `setBuffer`, `setRechargeRate`, `setIsWhitelisted`
- Relayer functions: All operational functions (deposit, withdraw, swap, transfer, etc.)

### 2.3 Freezer Role

**PASS** — `removeRelayer` moved from `MainnetController` directly to `AccessControls` contract. The `FREEZER_ROLE` holder calls `AccessControls.removeRelayer()` which revokes `RELAYER_ROLE`. Functionally identical, but now the freezer acts on the AccessControls contract rather than the Controller.

### 2.4 Error Format

**PASS** — The old code used `onlyRole(RELAYER)` from OZ which reverts with `AccessControlUnauthorizedAccount(address,bytes32)`. The new code's `FacetBase.onlyRole` modifier explicitly reverts with the same custom error: `AccessControlUnauthorizedAccount(msg.sender, role)`.

---

## Phase 3: Storage Layout and Collision Analysis

### 3.1 ERC-7201 Namespaced Storage

**PASS** — All ERC-7201 storage location hashes verified by independent computation:

| Namespace | Declared Slot | Computed Slot | Match |
|---|---|---|---|
| `sky.pau.storage.SharedController` | `0x77adf60b...1eb5cc00` | `0x77adf60b...1eb5cc00` | ✅ |
| `sky.pau.storage.Controller` | `0xee25394e...253c4d00` | `0xee25394e...253c4d00` | ✅ |
| `sky.pau.storage.AaveFacet` | `0xf780afd6...f394bd00` | `0xf780afd6...f394bd00` | ✅ |
| `sky.pau.storage.CCTPFacet` | `0xd2297bc3...5479da00` | `0xd2297bc3...5479da00` | ✅ |
| `sky.pau.storage.CurveFacet` | `0x9bdc08d6...f810b000` | `0x9bdc08d6...f810b000` | ✅ |
| `sky.pau.storage.UniswapV3Facet` | `0xffe4cc63...a27dbf00` | `0xffe4cc63...a27dbf00` | ✅ |
| `sky.pau.storage.UniswapV4Facet` | `0x87da7e51...c47ade00` | `0x87da7e51...c47ade00` | ✅ |
| `sky.pau.storage.OTCFacet` | `0x38103218...1f83200` | `0x38103218...1f83200` | ✅ |
| `sky.pau.storage.ERC4626Facet` | `0x2d0a4017...fdf76f00` | `0x2d0a4017...fdf76f00` | ✅ |
| `sky.pau.storage.LayerZeroFacet` | `0x35cbf4f8...6d72800` | `0x35cbf4f8...6d72800` | ✅ |
| `sky.pau.storage.CentrifugeFacet` | `0xc069081c...fa4f7900` | `0xc069081c...fa4f7900` | ✅ |

### 3.2 No Collision Between Namespaces

**PASS** — All 11 ERC-7201 slots are distinct. Each ends in `00` (per the ERC-7201 masking convention), making collision with standard Solidity layout slots (sequential from 0) astronomically unlikely.

### 3.3 ReentrancyGuard Storage Sharing

**PASS** — Both `Controller` and `FacetBase` inherit OpenZeppelin's `ReentrancyGuard` (v5.x), which uses `uint256 private _status` at slot 0. Since facets execute via `delegatecall` from `Controller`, they share the same reentrancy guard state. This is correct and intentional — a reentrancy attempt through the Controller's fallback will be caught by the shared guard.

### 3.4 Fresh Deployment — No Migration Risk

**PASS** — The new `Controller` is deployed with empty storage. Storage layout differences between old `MainnetController` (sequential slots) and new `Controller` (ERC-7201 namespaced) are NOT a migration risk because there is no in-place upgrade.

---

## Phase 4: Logic Equivalence — Function-by-Function

### 4.1 AaveFacet ← AaveLib

**PASS** — All logic identical:
- `deposit`: Rate limit decrease → slippage check → approve → supply → balance check. Identical parameter ordering and computation.
- `withdraw`: Pool withdraw → rate limit decrease/increase. Identical.
- `setMaxSlippage`: Has zero-address check (AaveFacet adds `require(aToken != address(0))`). Old code had the check on `MainnetController.setMaxSlippage` (shared). ✅

### 4.2 CCTPFacet ← CCTPLib

**PASS** — All logic identical:
- `transfer` / `transferWithFee`: Rate limit decrease → recipient check → fee cap check → approve → loop burn. Identical loop logic with `burnLimitsPerMessage` chunking.
- `setMaxFeeCap` / `setMintRecipient`: Identical validation.
- Constants: `DESTINATION_CALLER`, `MAX_FEE`, `MAX_FINALITY_THRESHOLD` — all identical values.

### 4.3 CentrifugeFacet ← CentrifugeLib

**PASS** — All logic identical:
- Cancel/claim deposit/redeem requests: Same `REQUEST_ID = 0`, same calls to `ICentrifugeV3VaultLike`.
- `transferShares`: Same spoke lookup via `baseManager()`, same rate limit key construction.
- `setRecipient`: Identical validation and storage.

Note: CentrifugeFacet uses `LIMIT_DEPOSIT = keccak256("LIMIT_7540_DEPOSIT")` and `LIMIT_REDEEM = keccak256("LIMIT_7540_REDEEM")` — same as old `CentrifugeLib` which reused `ERC7540Lib.LIMIT_DEPOSIT/LIMIT_REDEEM`.

### 4.4 CurveFacet ← CurveLib

**PASS** — All logic identical:
- `swap`: Index validation → stored_rates → slippage check → rate limit → approve → exchange. Identical.
- `addLiquidity`: Slippage via virtual_price → rate limit → add_liquidity → swap rate limit. Identical `_applySwapRateLimit` logic.
- `removeLiquidity`: Slippage check → remove_liquidity → aggregate rate limit. Identical.
- `setMaxSlippage`: Has zero-address check ✅.

### 4.5 DAIUSDSFacet ← DAIUSDSLib

**PASS** — `swapUSDSToDAI` and `swapDAIToUSDS`: Same approve → convert logic. Constructor immutables (`dai`, `daiUSDS`, `usds`) replace Ethereum.* constants.

### 4.6 ERC4626Facet ← ERC4626Lib

**PASS** — All logic identical:
- `deposit`: Rate limit → approve → deposit → shares check → exchange rate check. Identical.
- `withdraw`: Rate limit decrease → withdraw → shares check → rate limit increase. Identical.
- `redeem`: Redeem → assets check → rate limit decrease/increase. Identical.
- `setMaxExchangeRate`: Same zero-address check, same `_getExchangeRate` calculation. Identical.
- `EXCHANGE_RATE_PRECISION = 1e36` — Same constant.

### 4.7 ERC7540Facet ← ERC7540Lib

**PASS** — All four functions identical:
- `requestDeposit`: Rate limit → approve → requestDeposit call. Identical.
- `claimDeposit`: Rate limit existence check → maxMint → mint call. Identical.
- `requestRedeem`: Convert shares → rate limit → requestRedeem call. Identical.
- `claimRedeem`: Rate limit existence check → maxWithdraw → withdraw call. Identical.

### 4.8 FarmFacet ← FarmLib

**PASS** — `deposit` and `withdraw`: Same approve → stake/withdraw + getReward. Identical.

### 4.9 LayerZeroFacet ← LayerZeroLib

**PASS** — `transfer` function: Same rate limit key → recipient check → approvalRequired check → quoteOFT → quoteSend → send → refund. Identical logic including the 200,000 gas option and refund mechanism.
- `setRecipient`: Identical.
- Retains the "!!! deployed without integration testing !!!" warning comment.

### 4.10 MapleFacet ← MapleLib

**PASS** — `requestRedemption` and `cancelRedemption`: Identical rate limit logic and calls. Same `convertToAssets` calculation for rate limiting.

### 4.11 MerklFacet ← MerklLib

**PASS** — `toggleOperator`: Same proxy → distributor → toggleOperator call. `distributor` now constructor immutable instead of mutable state.

### 4.12 OTCFacet ← OTCLib

**PASS with findings** — Core logic equivalent with structural improvements:

- `send`: Same whitelist check → normalize to 18 decimals → rate limit → swap-ready check → state update → transfer. Identical.
- `claim`: Same buffer check → whitelist check → balance query → claimed18 accumulation → transferFrom. Identical.
- `getClaimWithRecharge` and `isSwapReady`: Same computation. Identical.

**Structural change:** Old code used a flat `OTC` struct with 5 fields in a single mapping. New code separates into `Parameters` (buffer, rechargeRate18, maxSlippage, assetWhitelisted) and `State` (sent18, sentTimestamp, claimed18) in two separate mappings keyed by exchange. This is cleaner and functionally equivalent.

**Finding — see F-02:** `setMaxSlippage` adds `require(maxSlippage > 0)`.

### 4.13 PendleFacet ← PendleLib

**PASS** — `redeem`: Same expired check → minAmountOut check → pyRedeem → rate limit. Identical helper `_createSimpleTokenOutput`. `router` now constructor immutable instead of mutable state.

### 4.14 PSMFacet ← PSMLib

**PASS** — `swapUSDSToUSDC` and `swapUSDCToUSDS`: Same approve → swap → approve → swap chain. Same PSM fill() loop for chunked swaps. All addresses now constructor immutables.

### 4.15 PSM3Facet ← PSM3Lib

**PASS** — `deposit` and `withdraw`: Same approve → PSM3.deposit/withdraw → rate limit. Identical.

### 4.16 SparkVaultFacet ← SparkVaultLib

**PASS** — `take`: Same rate limit → sparkVault.take call. Identical.

### 4.17 SuperstateFacet ← SuperstateLib

**PASS** — `subscribe`: Same rate limit → approve → subscribe call. Identical.

### 4.18 TransferAssetFacet ← TransferAssetLib

**PASS** — `transfer`: Same rate limit with `makeAddressAddressKey` → transfer with return data check. Identical, including safe transfer return data validation.

### 4.19 UniswapV3Facet ← UniswapV3Lib + UniswapV3UtilsLib + UniswapV3OracleLib

**PASS** — Most complex facet, all logic verified line-by-line:

- **swap**: Same tick delta check → TWAP check → minAmountOut check → approve → getPoolData → swap → balance diff → clear approval → rate limit. Identical.
- **addLiquidity**: Same parameter validation → approve both tokens → mint/increase → liquidity check → clear approvals → rate limits. Identical.
- **removeLiquidity**: Same validation → decrease → collect → slippage check → rate limits. Identical.
- **_getPosition**: Same assembly decode with sign extension for int24. Identical.
- **_getExpectedAmounts**: Same TWAP oracle → LiquidityAmounts → conditional amount deltas. Identical.
- **_validateMinAmount**: Same threshold calculation via FullMath.mulDiv. Identical.
- **_checkSlippage**: Identical formula `minAmount >= (amount * maxSlippage) / 1e18`.
- **UniswapV3Utils.consult**: Identical to `UniswapV3OracleLib.consult` — same observe → tickCumulativesDelta → negative rounding logic. Identical.
- **UniswapV3Utils.getAmount0Delta/getAmount1Delta**: Identical to `UniswapV3UtilsLib` — same math including divRoundingUp and signed overloads.

Admin setters:
- `setMaxTickDelta`, `setLiquidityLowerTickBound`, `setLiquidityUpperTickBound`, `setTWAPSecondsAgo`: All identical validation logic.

**Finding — see F-01:** `setMaxSlippage` is MISSING zero-address check.

### 4.20 UniswapV4Facet ← UniswapV4Lib

**PASS** — All logic verified:

- **mintPosition**: Same tick limit check → poolKey lookup → poolId match → calldata build → increaseLiquidity. Identical.
- **increasePosition**: Same ownership check → poolKey + info lookup → tick limit check → calldata build → increaseLiquidity. Identical.
- **decreasePosition**: Same poolKey lookup → poolId match → calldata build → decreaseLiquidity. Identical.
- **swap**: Slippage check → poolKey → tokenIn validation → normalize → rate limit → build calldata → approve → execute → reset approval. Identical.
- **_approveWithPermit2**: Same 3-step approval (reset → approve → Permit2.approve). Identical including the fire-and-forget reset pattern.
- **_checkTickLimits**: Same validation. Uses `storage` reference instead of `memory`, functionally identical.
- **_getModifyLiquiditiesCallData**: Same actions + params encoding. Identical.
- **_getSwapCallData**: Same ExactInputSingleParams + UniversalRouter.execute encoding. Identical.

**Intentional change:** `_PERMIT2`, `_POSITION_MANAGER`, `_ROUTER` changed from hardcoded constants to constructor-injected immutables. This enables multi-chain deployment.

**Intentional change:** `maxSlippages` mapping changed from `mapping(address => uint256)` keyed by `address(uint160(uint256(poolId)))` to `mapping(bytes32 => uint256)` keyed by full `poolId`. This is a correctness improvement — the old truncation to address lost the upper 96 bits of the poolId.

### 4.21 USDEFacet ← USDELib

**PASS** — All functions identical:
- `setDelegatedSigner` / `removeDelegatedSigner`: Same minter calls. Identical.
- `prepareMint` / `prepareBurn`: Same rate limit → approve. Identical.
- `cooldownAssets` / `cooldownShares`: Same rate limit logic. Identical.
- `unstakeSUSDE`: Same proxy → susde.unstake(proxy). Identical.

### 4.22 USDSFacet ← USDSLib

**PASS** — `mint` and `burn`: Same vault draw/wipe + buffer transfer. Identical.

### 4.23 WEETHFacet ← WEETHLib

**PASS** — All functions identical:
- `deposit`: Same WETH unwrap → eETH deposit → weETH wrap → slippage check. Identical.
- `requestWithdraw`: Same weETH unwrap → eETH shares check → rate limit → requestWithdraw. Identical.
- `claimWithdrawal`: Same rate limit check → module.claimWithdrawal. Identical.

### 4.24 WrapProxyETHFacet ← WrapProxyETHLib

**PASS** — `wrapAll`: Same proxy.balance check → doCallWithValue to WETH. Identical.

### 4.25 WSTETHFacet ← WSTETHLib

**PASS** — All functions identical:
- `deposit`: Same WETH unwrap → doCallWithValue to wsteth. Identical.
- `requestWithdraw`: Same stETH conversion → rate limit → approve → requestWithdrawalsWstETH. Identical.
- `claimWithdrawal`: Same balance diff → wrap ETH. Identical.

---

## Phase 5: Specific Risk Areas

### 5.1 UniswapV3 Oracle (consult function)

**PASS** — `UniswapV3Utils.consult` is identical to `UniswapV3OracleLib.consult`. Same `observe` call, same `tickCumulativesDelta` computation, same negative-infinity rounding, same `harmonicMeanLiquidity` calculation with `secondsAgoX160`.

### 5.2 UniswapV4 Addresses (Hardcoded → Immutable)

**PASS** — `_PERMIT2`, `_POSITION_MANAGER`, `_ROUTER` moved from hardcoded constants in `UniswapV4Lib` to constructor-injected `immutable` values in `UniswapV4Facet`. This is intentional for multi-chain deployment via `spark-address-registry`. Deployment scripts must set these correctly.

### 5.3 OTC State Structure

**PASS** — Old: single `OTC` struct with 5 fields in one mapping. New: split into `Parameters` (config) and `State` (runtime) in two separate mappings. Functionally identical reads and writes; cleaner separation of concerns.

### 5.4 setMaxSlippage Fragmentation (5 facets)

**FINDING — see details below**

Old system: Single `MainnetController.setMaxSlippage(address pool, uint256 maxSlippage)` writing to one shared `mapping(address => uint256) maxSlippages`.

New system: 5 separate `setMaxSlippage` functions, each writing to its own facet-specific ERC-7201 storage:
1. `AaveFacet.setMaxSlippage(address aToken, uint256 maxSlippage)` — has zero-address check ✅
2. `CurveFacet.setMaxSlippage(address pool, uint256 maxSlippage)` — has zero-address check ✅
3. `OTCFacet.setMaxSlippage(address exchange, uint256 maxSlippage)` — has zero-address AND non-zero slippage checks ✅
4. `UniswapV3Facet.setMaxSlippage(address pool, uint256 maxSlippage)` — **MISSING zero-address check** ⚠️
5. `UniswapV4Facet.setMaxSlippage(bytes32 poolId, uint256 maxSlippage)` — bytes32 key, zero-check N/A ✅

### 5.5 Fallback Function Security

**PASS** — The `Controller.fallback()`:
- Reverts on `facet == address(0)` (unregistered selector) ✅
- Uses `delegatecall` with selector replacement ✅
- Correctly forwards return data/reverts via assembly ✅
- Does NOT use `nonReentrant` on the fallback itself (the delegated facet function handles reentrancy) ✅

### 5.6 Dispatch Selector Collision Risk

**PASS** — `setDispatch` maps `callSelector → (facet, delegateSelector)`. Two different external selectors CANNOT map to the same facet function unless explicitly configured. The admin controls this mapping entirely. Standard diamond hygiene.

### 5.7 Per-Facet Events Replace Shared Events

**INFORMATIONAL** — The original `MaxSlippageSet(address pool, uint256 maxSlippage)` event is replaced by 5 per-facet events:
- `AaveMaxSlippageSet`
- `CurveMaxSlippageSet`
- `OTCMaxSlippageSet`
- `UniswapV3MaxSlippageSet`
- `UniswapV4MaxSlippageSet`

Off-chain monitoring must be updated to listen for these new event signatures.

### 5.8 Controller.setDispatch Reentrancy

**PASS** — `setDispatch` uses `nonReentrant` and `DEFAULT_ADMIN_ROLE` check. Cannot be manipulated during a facet execution.

### 5.9 Immutable vs Mutable State Variables

**INFORMATIONAL** — The following were mutable state variables on `MainnetController` but are now constructor immutables on facets:
- `uniswapV3PositionManager`, `uniswapV3Router` → `UniswapV3Facet.positionManager`, `.router`
- `pendleRouter` → `PendleFacet.router`
- `merklDistributor` → `MerklFacet.distributor`
- `ethenaMinter`, `susde`, `usdc`, `usde` → `USDEFacet` immutables
- `cctp`, `usdc` → `CCTPFacet` immutables
- `vault`, `usds` → `USDSFacet` immutables
- `dai`, `daiUSDS`, `usds` → `DAIUSDSFacet` immutables
- All PSM-related addresses → `PSMFacet` immutables
- `weth`, `weeth` → `WEETHFacet` immutables
- `weth`, `wsteth`, `withdrawQueue` → `WSTETHFacet` immutables

**Impact:** Changing any of these requires redeploying the facet and updating the dispatch mapping. This is more secure (no admin key compromise risk for protocol addresses) but less flexible.

---

## Phase 6: Missing/Added Functionality

### 6.1 Removed Admin Setters (Intentional)

The following admin functions from `MainnetController` are REMOVED, replaced by constructor immutables:
- `setUniswapV3PositionManager` → `UniswapV3Facet.positionManager` (immutable)
- `setUniswapV3SwapRouter` → `UniswapV3Facet.router` (immutable)
- `setPendleRouter` → `PendleFacet.router` (immutable)
- `setMerklDistributor` → `MerklFacet.distributor` (immutable)

**Assessment:** Intentional security improvement. These addresses change extremely rarely. Redeploying a facet is acceptable for such changes.

### 6.2 Removed State-Variable Getters

The following public state-variable getters from `MainnetController` are removed:
- `buffer()` — was `address public buffer` (derived from `vault.buffer()`)
- `gem()` — was interface definition on MainnetController
- `dai()`, `usds()`, `usdc()`, etc. — now available as `immutable` getters on relevant facets

**Assessment:** Not a functional regression. Values are accessible via facet-specific getters.

### 6.3 Removed LIMIT_* Public Variables

`MainnetController` exposed all rate limit keys as public state variables (e.g., `LIMIT_AAVE_DEPOSIT`). The new facets expose them as `public constant` on each facet.

**Assessment:** Functionally equivalent but distributed across facets.

### 6.4 Added View Functions

New getter functions added to facets for reading facet-specific storage:
- `AaveFacet.getMaxSlippage(aToken)`
- `CurveFacet.getMaxSlippage(pool)`
- `OTCFacet.getBuffer(exchange)`, `getMaxSlippage(exchange)`, `getRechargeRate(exchange)`, `getIsWhitelisted(exchange, asset)`, `getState(exchange)`
- `UniswapV3Facet.getMaxSlippage(pool)`, `getMaxTickDelta(pool)`, `getLiquidityTickBounds(pool)`, `getTWAPSecondsAgo(pool)`
- `UniswapV4Facet.getMaxSlippage(poolId)`, `getTickLimits(poolId)`
- `CCTPFacet.getMaxFeeCap()`, `getMintRecipient(domain)`
- `LayerZeroFacet.getRecipient(eid)`
- `CentrifugeFacet.getRecipient(centrifugeId)`
- `ERC4626Facet.getMaxExchangeRate(token)`

**Assessment:** Improvement. Old code relied on auto-generated public variable getters; new code has explicit view functions.

### 6.5 ForeignController Unification

**PASS** — `ForeignController` is eliminated. The same facets serve both mainnet and foreign chains, configured per-chain via constructor immutables and dispatch mappings. This reduces code duplication and audit surface.

### 6.6 removeRelayer Moved to AccessControls

**PASS** — `removeRelayer(address)` moved from the Controller to the `AccessControls` contract. The freezer calls `AccessControls.removeRelayer()` instead of `MainnetController.removeRelayer()`. Functionally equivalent — both revoke `RELAYER_ROLE`.

---

## Phase 7: Test Coverage

### 7.1 Integration Test Base

**PASS** — `Controller_TestBase` (test/integration/TestBase.t.sol) correctly deploys:
- `AccessControls` with admin
- `ALMProxy` with admin
- `RateLimits` with admin
- `Controller` wired to all three
- Grants `CONTROLLER` role on proxy to controller
- Grants `RELAYER_ROLE` and `FREEZER_ROLE` on access controls

This exercises the full dispatch path.

### 7.2 Integration Tests for Admin Setters

**PASS** — Integration tests exist for the 9 facets with admin setters:

| Facet | Integration Test File | setMaxSlippage Tested |
|---|---|---|
| AaveFacet | test/integration/facets/AaveFacet.t.sol | ✅ |
| CCTPFacet | test/integration/facets/CCTPFacet.t.sol | N/A (no maxSlippage) |
| CentrifugeFacet | test/integration/facets/CentrifugeFacet.t.sol | N/A |
| CurveFacet | test/integration/facets/CurveFacet.t.sol | ✅ |
| ERC4626Facet | test/integration/facets/4626Facet.t.sol | N/A (maxExchangeRate) |
| LayerZeroFacet | test/integration/facets/LayerZero.t.sol | N/A |
| OTCFacet | test/integration/facets/OTCFacet.t.sol | ✅ |
| UniswapV3Facet | test/integration/facets/UniswapV3.t.sol | ✅ |
| UniswapV4Facet | test/integration/facets/UniswapV4Facet.t.sol | ✅ |

### 7.3 Relayer-Only Facets (No Admin Tests Needed)

**PASS** — The following 16 facets are relayer-only and correctly have no admin setter tests:
DAIUSDSFacet, ERC7540Facet, FarmFacet, MapleFacet, MerklFacet, PendleFacet, PSMFacet, PSM3Facet, SparkVaultFacet, SuperstateFacet, TransferAssetFacet, USDEFacet, USDSFacet, WEETHFacet, WrapProxyETHFacet, WSTETHFacet

### 7.4 Fork Test Coverage

**PASS** — Fork tests exist for all protocol integrations:
- Mainnet: Aave, CCTP, Centrifuge, Curve, DAIUSDS, Ethena, ERC4626, Farm, LayerZero, Maple, Merkl, OTC, Pendle, PSM, SparkVault, Superstate, TransferAsset, UniswapV3, UniswapV4, USDS, WEETH, WrapProxyETH, WSTETH
- Base: Aave, Curve, Merkl, Morpho, Pendle, PSM3, SparkVault, TransferAsset, UniswapV3

### 7.5 Controller Unit Tests

**PASS** — `test/unit/Controller.t.sol` and `test/integration/Controller.t.sol` exist for testing dispatch mechanism, access control, and fallback behavior.

---

## Consolidated Findings

### F-01: UniswapV3Facet.setMaxSlippage Missing Zero-Address Check [MEDIUM]

**Severity:** Medium
**Location:** `src/facets/uniswap-v3/UniswapV3Facet.sol:192-198`

**Description:** `UniswapV3Facet.setMaxSlippage` does not validate that `pool != address(0)`, unlike the original `MainnetController.setMaxSlippage` which had `require(pool != address(0), "MC/pool-zero-address")`. All other address-keyed `setMaxSlippage` implementations (AaveFacet, CurveFacet, OTCFacet) include the zero-address check.

**Impact:** An admin could accidentally set a maxSlippage for `address(0)`, which would be a no-op but creates inconsistency. Low practical impact (admin-only function, no funds at risk) but breaks the pattern.

**Recommendation:** Add `require(pool != address(0), "UniswapV3Facet/pool-zero-address");` to `setMaxSlippage`.

---

### F-02: OTCFacet.setMaxSlippage Adds `maxSlippage > 0` Restriction [LOW]

**Severity:** Low
**Location:** `src/facets/otc/OTCFacet.sol:62`

**Description:** `OTCFacet.setMaxSlippage` adds `require(maxSlippage > 0, "OTCFacet/max-slippage-zero")` which did not exist in the original `MainnetController.setMaxSlippage`. The old code allowed setting `maxSlippage = 0` for any pool/exchange.

**Impact:** This is a **behavior change** — admin cannot set maxSlippage to 0 for an OTC exchange. In the old system, setting maxSlippage to 0 effectively disabled the exchange (since `isSwapReady` returns false when maxSlippage is 0). In the new system, the admin must use a different mechanism to disable an exchange (e.g., not setting it at all, or revoking the buffer). Since the new OTCFacet has `maxSlippage` inside a nested `Parameters` struct (defaulting to 0 for unconfigured exchanges), a fresh exchange already starts disabled. The restriction only prevents *re-disabling* an exchange by setting slippage back to 0.

**Recommendation:** Consider whether disabling an exchange by setting maxSlippage=0 is a needed admin capability. If so, remove the `> 0` check or add a separate `disableExchange` function.

---

### F-03: Per-Facet Event Signature Changes [LOW]

**Severity:** Low
**Location:** All facets with `setMaxSlippage`

**Description:** The original `MaxSlippageSet(address indexed pool, uint256 maxSlippage)` event is replaced by 5 per-facet events with different names:
- `AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage)`
- `CurveMaxSlippageSet(address indexed pool, uint256 maxSlippage)`
- `OTCMaxSlippageSet(address indexed exchange, uint256 maxSlippage)`
- `UniswapV3MaxSlippageSet(address indexed pool, uint256 maxSlippage)`
- `UniswapV4MaxSlippageSet(bytes32 indexed poolId, uint256 maxSlippage)`

Similarly, other events have been renamed (e.g., `MintRecipientSet` → `CCTPMintRecipientSet`, `UniswapV3PoolMaxTickDeltaSet` → `UniswapV3MaxTickDeltaSet`, etc.).

**Impact:** Off-chain monitoring, indexers, and dashboards that listen for the old event signatures will miss these events. No on-chain impact.

**Recommendation:** Update all off-chain infrastructure to monitor the new event signatures before migration.

---

### F-04: UniswapV4 maxSlippage Key Change (bytes32 vs truncated address) [INFORMATIONAL]

**Severity:** Informational
**Location:** `src/facets/uniswap-v4/UniswapV4Facet.sol`

**Description:** The old `UniswapV4Lib.swap` looked up maxSlippage via `maxSlippages[address(uint160(uint256(poolId)))]` — truncating the bytes32 poolId to an address to fit the shared `mapping(address => uint256)`. The new `UniswapV4Facet` correctly uses `mapping(bytes32 => uint256)` with the full `poolId` key.

**Impact:** This is a correctness improvement. The old truncation could theoretically cause collisions if two pool IDs shared the same lower 160 bits (astronomically unlikely in practice). The migration spell must set maxSlippage using the new bytes32 key format.

---

## Summary

| Phase | Result |
|---|---|
| Phase 1: Dispatch & Interface | **PASS** |
| Phase 2: Access Control | **PASS** |
| Phase 3: Storage Layout | **PASS** — All ERC-7201 slots verified |
| Phase 4: Logic Equivalence | **PASS** — All 25 facets verified |
| Phase 5: Specific Risk Areas | **PASS with 1 MEDIUM finding** |
| Phase 6: Missing/Added Functionality | **PASS** — All changes intentional |
| Phase 7: Test Coverage | **PASS** — Adequate coverage |

**Final Verdict:** The refactor is functionally equivalent to the production code. The diamond-style architecture is correctly implemented with ERC-7201 namespaced storage, proper reentrancy guard sharing, and clean separation of concerns. The one medium finding (F-01) should be remediated before deployment.
