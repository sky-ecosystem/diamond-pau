# Liquidity Operations

This document describes the stablecoin market making, swapping, and liquidity provision functionality in PAU.

## Overview

PAU performs liquidity operations across multiple venues:

| Venue          | Operations                  | Use Case                                       |
| -------------- | --------------------------- | ---------------------------------------------- |
| **Curve**      | Add/remove liquidity, swaps | Deep stablecoin liquidity pools                |
| **Uniswap V3** | Add/remove liquidity, swaps | Stablecoin LP positions and swaps via V3 pools |
| **Uniswap V4** | Swaps, positions            | On-chain stablecoin swaps                      |
| **OTC Desks**  | Offchain swaps              | High-volume institutional liquidity            |

---

## Curve Integration

### Supported Operations

- **Add Liquidity:** Deposit stablecoins into Curve pools to receive LP tokens
- **Remove Liquidity:** Burn LP tokens to receive underlying stablecoins
- **Swaps:** Exchange between stablecoins in Curve pools

### Rate Limiting

Curve operations use several rate limit keys per pool:

- **Aggregate deposit rate limit:** Controls the value deposited into pools
- **Asset deposit rate limits:** Controls the value deposited into pools for a specific token
- **Asset Swap rate limits:** Controls the implicit swap value when deposits are imbalanced for a specific token
- **Aggregate withdraw rate limit:** Controls the value withdrawn from pools
- **Asset withdraw rate limits:** Controls the value withdrawn from pools for a specific token

Since adding liquidity in Curve handles input asset rebalancing with "virtual swaps" to keep the pool's ratio of assets constant, the asset swap rate limits for each token must also be set in order for the add liquidity operation to succeed, regardless if any assets were actually "swapped" in or out.

### Slippage Protection

All Curve operations require `maxSlippage` to be configured (cannot be zero). The slippage check uses the pool's virtual price to ensure minimum acceptable returns.

### Requirements

- Even though it relies on `stored_rates` for asset normalization, it is designed for 1:1 stablecoin or correlated asset pools of correlated assets (e.g. sUSDS/USDC or wstETH/WETH).

### Seeding Requirement

Curve pools must be seeded with initial liquidity before use. Seeding must be done to an unrecoverable address (e.g, address(1)). This will prevent any unintended behaviours.

---

## Uniswap V3 Integration

### Supported Operations

- **Swaps:** Exchange between assets via Uniswap V3 pools
- **Add Liquidity:** Mint a new position or increase an existing one
- **Remove Liquidity:** Decrease liquidity from an existing position and collect tokens

### Rate Limiting

Uniswap V3 operations use several rate limit keys per pool:

- **Aggregate deposit rate limit:** Controls the value deposited into pools
- **Asset deposit rate limits:** Controls the value deposited into pools for a specific token
- **Asset Swap rate limits:** Controls the swap value (amount spent) for a specific token
- **Aggregate withdraw rate limit:** Controls the value withdrawn from pools
- **Asset withdraw rate limits:** Controls the value withdrawn from pools for a specific token

### Slippage Protection

Uniswap V3 operations use different slippage models depending on the operation:

- **`addLiquidity` (mint and increase) and `removeLiquidity`:** Require the per-pool `maxSlippage` to be configured (cannot be zero). For add-liquidity, caller-supplied `min.amount0` / `min.amount1` are validated against TWAP-derived expected amounts before execution. For remove-liquidity, the same minimums are checked against the amounts actually received after execution.
- **`swap`:** Does not check `maxSlippage`. Requires a nonzero caller-supplied `minAmountOut` and uses a TWAP-derived `sqrtPriceLimitX96` bounded by the per-pool `swapMaxTickDelta` as the on-chain price boundary.

### Requirements

- Onboarded pools should be limited to those with 1:1 stablecoin pairs.
- Tick bounds and TWAP seconds must be configured before operations
- The ALMProxy must own the NFT position for increase/decrease operations
- Uses the pool's built-in TWAP oracle for price validation on swaps and liquidity additions, unlike V4 which does not rely on TWAP

See [UNIV3_UNIV4_COMPARISON.md](./UNIV3_UNIV4_COMPARISON.md) for a detailed comparison with Uniswap V4.

---

## Uniswap V4 Integration

### Supported Operations

- **Swaps:** Exchange between stablecoins via Uniswap V4 pools
- **Mint Positions:** Create liquidity positions (if applicable)
- **Increase Positions:** Deposit adfditional liquidity into an existing position
- **Decrease Positions:** Withdraw some or al the liquidity of an existing position

### Rate Limiting

Uniswap V4 operations use several rate limit keys per pool:

- **Aggregate deposit rate limit:** Controls the value deposited into pools
- **Asset deposit rate limits:** Controls the value deposited into pools for a specific token
- **Asset Swap rate limits:** Controls the implicit swap value when deposits are imbalanced for a specific token
- **Aggregate withdraw rate limit:** Controls the value withdrawn from pools
- **Asset withdraw rate limits:** Controls the value withdrawn from pools for a specific token

### Slippage Protection

Uniswap V4 operations use different slippage models depending on the operation:

- **`swap`:** Requires the per-pool `maxSlippage` to be configured (cannot be zero). Validates that the caller-supplied `amountOutMin`, normalized to 18 decimals, is no less than the normalized `amountIn` scaled by `maxSlippage`. This relies on the 1:1 equal-value assumption between the pool's tokens.
- **`mintPosition`, `increasePosition`, `decreasePosition`:** Do not check `maxSlippage`. They rely on caller-supplied `amount0Max` / `amount1Max` (mint and increase) or `amount0Min` / `amount1Min` (decrease) as boundaries enforced by the position manager, together with the per-pool tick limits (`tickLowerMin`, `tickUpperMax`, `maxTickSpacing`) on `mintPosition` and `increasePosition`.

### Requirements

- Onboarded pools should be limited to those with 1:1 stablecoin pairs.
- Tick limits must be configured for `mintPosition` and `increasePosition`
- `maxSlippage` must be configured per pool for `swap`
- Only hookless pools can be onboarded. Rate limit decreases are calculated from token balance differences before and after pool interactions, and empty `hookData` is passed. Pool hooks (if present) could manipulate token balances during the call to bypass the rate limit decrease.

### Seeding Requirement

Uniswap V4 pools must be seeded with initial liquidity before use. Seeding must be done to an unrecoverable address (e.g, address(1)). This will prevent any unintended behaviours.

---

## DualPool Integration

DualPool pools are Uniswap V4 pools whose liquidity is provisioned just-in-time by the DualPoolHook from hook-held (and ERC-4626 rehypothecated) reserves. They cannot be onboarded to the `UniswapV4Facet` for liquidity provision because the hook blocks LP entry through the PositionManager (entry and exit go through the hook's own share-based functions), and the `UniswapV4Facet` only allows hookless pools. The `DualPoolFacet` is a rate-limited LP allocator: the hook is owned by governance (the Spark Proxy) and its pools are permissionless, so pool lifecycle, configuration, and incident response are operated by governance directly on the hook, and the ALMProxy enters and exits as a regular LP. Swaps through DualPool pools go through the `UniswapV4Facet` swap path.

One facet instance is bound to one hook deployment via an immutable. The hook has no poolId to PoolKey registry, so interactive functions take the full `PoolKey` from calldata and derive `poolId = keccak256(abi.encode(key))`; `key.hooks` must match the facet's hook, so a fabricated key can only reach a disabled configuration.

### Supported Operations

- **Deposits:** Mint pool shares against both tokens (`deposit`)
- **Withdrawals:** Burn pool shares for both tokens (`withdraw`); exits keep working while a pool is paused

### Roles

- **`DEFAULT_ADMIN_ROLE`:** The per-pool `maxSlippage` and `priceRatio` that denominate the allocator value floors
- **`ALLOCATOR_ROLE`:** Rate-limited `deposit` and `withdraw`

Hook-side operations (pool creation, genesis bootstrap, JIT distribution updates, external deposit gating, pause and resume, vault approval levers) are the hook owner's, i.e. governance acting directly on the hook rather than through the facet.

### Rate Limiting

DualPool operations use several rate limit keys per pool:

- **Aggregate deposit rate limit:** Controls the 1e18-normalized value deposited into the pool across both tokens
- **Asset deposit rate limits:** Controls the value deposited per token
- **Aggregate withdraw rate limit:** Controls the 1e18-normalized value withdrawn from the pool across both tokens
- **Asset withdraw rate limits:** Controls the value withdrawn per token

Deposit and withdraw decrements are measured from ALMProxy balance deltas.

### Slippage Protection

Both allocator value paths are floored by the per-pool `maxSlippage` (zero disables the pool), computed onchain at execution time so a compromised allocator cannot weaken them:

- **`deposit`:** After the deposit, the minted shares must be redeemable (pro rata, via `previewWithdraw`) for at least `maxSlippage` of the value paid. This round-trip floor catches share-price skew (donation-style manipulation, vault share-price moves, hook mis-accounting) that per-token `amountMax` caps cannot express.
- **`withdraw`:** The caller-supplied minimums must be worth at least `maxSlippage` of the `previewWithdraw` value of the shares burned.

Each floor compares an aggregate value across both currencies rather than per-token amounts, because the token split of a deposit or withdrawal moves with pool price while the total value does not. Making those aggregates comparable requires knowing what one currency is worth in terms of the other, which is the per-pool `priceRatio`: the value of one whole unit of `currency1` in whole units of `currency0`, in 1e18 precision. A pegged pair is `1e18`.

Both halves must be non-zero before any allocator path opens, so a pool cannot be onboarded with floors that silently assume parity. For a non-pegged pair the ratio is load-bearing and governance must keep it current: a stale ratio weakens both floors in proportion to its drift from the true price.

### Requirements

- `maxSlippage` and `priceRatio` must both be configured per pool; either left at zero disables allocator operations.
- `maxSlippage` is capped at `1e18` and must be set strictly below it for `deposit` to be usable. The deposit floor compares what the minted shares redeem for against what was paid, and the hook rounds the deposit up while rounding the redemption down, so the round trip is lossy by design. At exactly `1e18`, `withdraw` still works but every `deposit` reverts.
- A non-pegged pair requires governance to maintain `priceRatio` as the market moves. Pegged stablecoin pairs (`priceRatio = 1e18`) are the intended case and need no maintenance.
- Deposits require authorization on the hook side: external deposits must be enabled for the pool, which is the intended permissionless configuration.
- Pool shares are pool-scoped and non-transferable; the only exit is `removeLiquidity`. Net asset accounting should read `previewWithdraw(key, sharesOf(key, proxy))`.
- When the pool's `minDepositBlocks` is non-zero, a withdrawal in the same block as a deposit reverts, and each deposit refreshes the lock for the ALMProxy's entire position in that pool. Allocator automation must sequence accordingly. Prefer `minDepositBlocks = 0` unless the hook's anti-fee-sniping property is specifically wanted: the lock is keyed on the depositor, and the ALMProxy is always the depositor, so any deposit, including a dust one, defers the whole position's exit. Note that a compromised allocator can also use a dust deposit to defer exits; the mitigation is the freezer removing the allocator role.
- The hook owner can pause pools, change distributions, and configures the ERC-4626 vaults that rehypothecate pool assets. `removeLiquidity` stays open under pause and needs no allowance, but a bricked vault can impair exits up to the vault-held portion. With governance as the hook owner these levers stay in-house; sizing via rate limits still bounds vault-side impairment.

---

## OTC Swaps (Offchain Swap Support)

The OTC swap module allows offchain swaps with OTC desks and exchanges while constraining capital outside the system.

### How It Works

1. Funds are sent from the ALM Proxy to the offchain destination
2. The contract prevents sending more funds until the required balance is returned
3. Acts as a gating mechanism: maximum `X` funds outside the system per approved exchange

This provides guarantees that at most `X` can be at risk per whitelisted (rate limited) OTC route, while allowing rapid throughput into high-liquidity offchain markets.

### System Diagram

![Offchain Swap Module](https://github.com/user-attachments/assets/9aed5b7f-0b6e-45e3-8ad8-10bc5016470d)

### OTC Swap Conditions

For an OTC swap to be performed, `isOtcSwapReady(exchange)` must return `true`. This function has two main components:

#### Slippage

`maxSlippages` mapped on `exchange`, used consistently with other parts of the controller. This value calculates a minimum viable amount to be returned from a swap for it to be considered complete.

#### Recharge Rate

The OTC struct contains a `rechargeRate` value expressed in 18 decimals of token per second. This value increases over time after the initial swap is sent.

**Purpose:** Prevents the configuration from bricking swapping functionality if an exchange returns an amount of funds that is materially below the configured `maxSlippage`. The mechanism allows the amount that can be sent as part of an OTC swap to virtually "recharge" over time, to respond to deviations in recent expected claims.

#### Ready Condition

An OTC swap is ready when:

$$claimedAmount + (blockTimestamp - sentTimestamp) \times rechargeRate \ge sentAmount \times maxSlippage$$

### OTC Buffer Configuration

OTC buffers require infinite allowance (`type(uint256).max`) to the ALMProxy. This allows atomic fund pulling during swap completion. `otcClaim` always attempts to transfer the entire buffer balance for a whitelisted (via rate limit) asset; with finite allowances, an attacker can donate a small amount to push balance above allowance, causing claim reverts and blocking OTC readiness when recharge is zero/low. See [Operational Requirements](./OPERATIONAL_REQUIREMENTS.md#otc-buffer-deployment) for deployment checklist.

---

## PSM Integration

There are two PSM integrations with different rate limit behaviors:

### Mainnet PSM (PSMFacet)

**Operations:** USDS ↔ USDC swaps (via DAI conversion)

| Operation        | Rate Limit                   |
| ---------------- | ---------------------------- |
| `swapUSDSToUSDC` | Decreases limit              |
| `swapUSDCToUSDS` | **Cancels** (restores) limit |

**Rationale:** Swapping USDC back to USDS returns value to the system, so rate limit is restored.

### PSM3 (PSM3Facet)

**Operations:** Deposit/withdraw assets to/from L2 PSM

| Operation  | Rate Limit                        |
| ---------- | --------------------------------- |
| `deposit`  | Decreases limit                   |
| `withdraw` | Decreases limit (no cancellation) |

**Design Decision:** No cancellation, no `minShares`.

**Rationale:**

- PSM3 will be deprecated soon
- The contract is immutable, limiting attack surface
- Prices cannot be manipulated due to 1:1 swap design

---

## Operational Requirements

For deployment checklists and configuration requirements, see [Operational Requirements](./OPERATIONAL_REQUIREMENTS.md).
