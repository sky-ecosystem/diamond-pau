# Swap Integration

This document describes the `SwapFacet`, which lets one PAU swap ERC-20 assets with another PAU at a governance-set par value. It is the on-chain swap mechanism between a Spark Savings vault PAU and the Spark Liquidity Layer (SLL) PAU described in the Spark Savings reorganization proposal (Phase 2). Code and chain state override this document.

## Overview

Two PAUs (each an `ALMProxy` with its own `Controller`, `AccessControls` and `RateLimits`) both wire the same `SwapFacet`. A swap is a single atomic call on one Controller:

1. The executing proxy **pushes** `amountIn` of `assetIn` to the counterparty proxy with `transfer`.
2. The executing proxy **pulls** `amountOut` of `assetOut` from the counterparty proxy with `transferFrom`, using a standing allowance that the counterparty's governance granted to the executing proxy.

`amountOut` is derived from admin-set par values, not from an oracle or a market. There is no external protocol: the only contracts touched are the two ERC-20 tokens and the two proxies.

```
        SLL PAU                                   Savings PAU
  ┌──────────────────┐                       ┌──────────────────┐
  │ Controller       │                       │ Controller       │
  │  └ SwapFacet     │                       │  └ SwapFacet     │
  │ ALMProxy ────────┼── transfer(USDS) ────►│ ALMProxy         │
  │          ◄───────┼── transferFrom(USDT) ─┤   (allowance to  │
  │                  │                       │    SLL ALMProxy) │
  └──────────────────┘                       └──────────────────┘
```

Either side can execute. The executing side's `RateLimits` and par values apply; the counterparty's only protection against the executing side is the allowance it granted.

## Trust Assumptions

| Party                                   | Trust                                                                                                                                                                                                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` (both PAUs)        | Fully trusted. Sets par values, standing allowances and rate limits. On Ethereum this is `Ethereum.SPARK_PROXY`, which executes Sky governance spells, so the proposal's "Sky governance updates the par value" maps onto this role.           |
| `ALLOCATOR_ROLE` (executing PAU)        | Assumed compromisable. Can only move value along routes that have a configured rate-limit key, at the configured par value, within the rate limit, and only against a counterparty that granted an allowance.                                   |
| Counterparty PAU                        | A Spark PAU under the same governance. Its allowance to the executing proxy is the hard bound on what a compromised executing Controller (not just a compromised allocator) could pull from it.                                                  |
| Tokens                                  | Standard, non-rebasing, fixed-decimals ERC-20s (USDS, USDT, USDC, sUSDS). Fee-on-transfer tokens are rejected at runtime by the balance-delta check. Tokens that return nothing (USDT) and tokens that return `bool` are both accepted.         |

## Functions

### `setParValue(address asset, uint256 parValue)` — `DEFAULT_ADMIN_ROLE`

Stores the USDS value of one whole unit of `asset` in 1e18 precision and snapshots `asset.decimals()`. `1e18` means the asset trades at par with USDS. `0` disables the asset for both legs. Lowering the par value of a deposit asset (e.g. USDT to `0.9e18`) is how governance applies a haircut: one USDS then buys `1 / 0.9` USDT, and one USDT buys `0.9` USDS.

Par values are per asset, not per counterparty, and they live on the executing PAU. If both PAUs can execute, governance sets them on both.

### `approve(address asset, address counterparty, uint256 allowance)` — `DEFAULT_ADMIN_ROLE`

Sets a standing ERC-20 allowance from this proxy to `counterparty` through `ApproveLib` (handles USDT's non-zero-to-non-zero restriction). This is the one sanctioned standing approval of the facet: without it the counterparty's `swap` cannot pull anything from this proxy. Setting it to `0` halts the counterparty's pulls immediately. The `counterparty` must not be this proxy.

### `swap(address counterparty, address assetIn, address assetOut, uint256 amountIn, uint256 minAmountOut)` — `ALLOCATOR_ROLE`

1. `_decreaseRateLimit(getSwapRateLimitKey(assetIn, assetOut, counterparty), amountIn)` — enforcing; reverts on an unconfigured route.
2. `amountOut = getAmountOut(assetIn, assetOut, amountIn)` — reverts if either par value is unset; rounds down.
3. Requires `amountOut != 0` and `amountOut >= minAmountOut`.
4. `proxy.doCall(assetIn, transfer(counterparty, amountIn))`.
5. `proxy.doCall(assetOut, transferFrom(counterparty, proxy, amountOut))`.
6. Requires the proxy's `assetOut` balance to have grown by exactly `amountOut`.
7. `_tryIncreaseRateLimit(getSwapRateLimitKey(assetOut, assetIn, counterparty), amountOut)` — restores the opposite route when configured, no-op otherwise.
8. Emits `SwapExecuted`.

No approval is created on the executing side; the push leg uses `transfer`.

### View functions

- `getAmountOut(assetIn, assetOut, amountIn)`: `amountIn * parValueIn * 10^decimalsOut / (parValueOut * 10^decimalsIn)`, rounded down.
- `getAssetParameters(asset)`: `(parValue, decimals)`.
- `getSwapRateLimitKey(assetIn, assetOut, counterparty)`.

## Rate Limits

| Constant      | Key                                                                 | Decreased by          | Restored by                                              |
| ------------- | ------------------------------------------------------------------- | --------------------- | -------------------------------------------------------- |
| `LIMIT_SWAP`  | `makeAddressAddressAddressKey(LIMIT_SWAP, assetIn, assetOut, counterparty)` | `swap` by `amountIn` (native decimals of `assetIn`) | `swap` in the opposite direction by `amountOut`, via try-increase |

The key includes the direction and the counterparty, so configuring `(USDS, USDT, savingsProxy)` on the SLL PAU allows the SLL to sell USDS for USDT to that one PAU and nothing else. Amounts are in the native decimals of `assetIn`, so a USDS route is sized in 1e18 units and a USDT route in 1e6 units.

The restore follows the PSM precedent: swapping back returns value to the executing PAU, so the outbound budget is refilled (capped at `maxAmount`).

## Events

```solidity
event SwapAllowanceSet(address indexed asset, address indexed counterparty, uint256 allowance);
event SwapExecuted(address indexed counterparty, address indexed assetIn, address indexed assetOut, uint256 amountIn, uint256 amountOut);
event SwapParValueSet(address indexed asset, uint256 parValue, uint8 decimals);
```

## Error Strings

| Error                                   | Cause                                                                     |
| --------------------------------------- | ------------------------------------------------------------------------- |
| `SwapFacet/asset-zero-address`          | `approve` or `setParValue` with `asset == address(0)`                      |
| `SwapFacet/counterparty-zero-address`   | `approve` with `counterparty == address(0)`                                |
| `SwapFacet/counterparty-equals-proxy`   | `approve` with `counterparty == proxy`                                     |
| `SwapFacet/same-asset`                  | `swap` with `assetIn == assetOut`                                          |
| `SwapFacet/zero-amount-in`              | `swap` with `amountIn == 0`                                                |
| `SwapFacet/par-value-in-not-set`        | `assetIn` has no par value                                                 |
| `SwapFacet/par-value-out-not-set`       | `assetOut` has no par value                                                |
| `SwapFacet/zero-amount-out`             | `amountIn` rounds down to zero `assetOut`                                  |
| `SwapFacet/min-amount-out-not-met`      | `amountOut < minAmountOut`                                                 |
| `SwapFacet/transfer-failed`             | Push leg returned `false` or non-standard return data                      |
| `SwapFacet/transferFrom-failed`         | Pull leg returned `false` or non-standard return data                      |
| `SwapFacet/amount-out-mismatch`         | Pull leg delivered a different amount than requested (fee-on-transfer)     |

Plus the inherited `RateLimits/zero-maxAmount` and `RateLimits/rate-limit-exceeded`, and `ApproveLib/approve-failed` from `approve`.

## Operational Requirements

Configuration order for an SLL PAU (`A`) and a Savings PAU (`B`) trading USDS against USDT:

1. Wire `SWAP_FACET` on both Controllers (`beacon.setIntegration`, then `updateIntegrations` on each).
2. On both Controllers: `swap_setParValue(USDS, 1e18)` and `swap_setParValue(USDT, 1e18)`.
3. `A.swap_approve(USDS, B.proxy, cap)` and `B.swap_approve(USDT, A.proxy, cap)`. Each cap is the maximum the other PAU can ever pull, independent of rate limits.
4. On `A.rateLimits`: set `(USDS, USDT, B.proxy)` for selling USDS and, if `A` may also buy USDS back, `(USDT, USDS, B.proxy)`. On `B.rateLimits`: the mirror routes with `A.proxy` as counterparty.
5. Grant `ALLOCATOR_ROLE` on each PAU to the relayer that will execute from that side.

Halting swaps (the proposal's FREEZER action) is done with existing controls, in increasing order of reach:

- the allocator role admin revokes `ALLOCATOR_ROLE` from the executing relayer;
- `DEFAULT_ADMIN_ROLE` sets the route's rate limit `maxAmount` to `0`, sets the asset's par value to `0`, or sets the allowance granted to the counterparty to `0` (this last one also stops the *counterparty's* pulls);
- `DEFAULT_ADMIN_ROLE` calls `removeIntegrations(["SWAP_FACET"])`.

Monitoring: `SwapExecuted` on both Controllers, and the two standing allowances.

## Failure Modes and Limits

- **Rounding.** `amountOut` rounds down, so the executing PAU bears at most one wei of `assetOut` per swap. A round trip at par loses at most that much per leg.
- **Decimals.** Decimals are snapshotted in `setParValue`; a token whose `decimals()` later changes keeps the old pricing until governance re-sets the par value. The facet makes no external view call while pricing.
- **Allowance is per asset, not per route.** An allowance granted to a counterparty proxy can be consumed by any route the counterparty's own Controller has configured; the counterparty's rate limits and par values decide what it gives in exchange.
- **Sibling Controllers.** Reentrancy guards are per Controller. If either proxy is shared with other Controllers, the balance-delta check in step 6 observes the shared proxy's balance; a sibling operation on the same proxy in the same transaction would make it revert rather than mis-account.
- **Not covered.** No oracle, no sUSDS share valuation: swaps between an ERC-4626 share and a stablecoin are not supported at a moving rate. Convert shares to the underlying with `ERC4626Facet` on the owning PAU and swap the underlying.
