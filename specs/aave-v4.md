---
facet: AaveV4Facet
dir: aave-v4
chains: [mainnet]
integration_doc: AAVEV4_INTEGRATION.md
dependencies: []
---

# AaveV4 Integration Spec

## Summary

Supply-only integration with Aave V4 hub-and-spoke lending markets. The facet supplies underlying assets from the ALMProxy into a market identified by `(spoke, reserveId)` and withdraws them back, capturing lending yield on idle stablecoin and WETH balances. Positions are non-tokenized share balances in spoke storage; there is no aToken or receipt token, so the facet holds no intermediate asset.

## External protocol

- **Protocol:** Aave V4 (hub-and-spoke), live on mainnet since March 2026. Behavior in this spec verified against [aave/aave-v4](https://github.com/aave/aave-v4) at commit `cfdf931c8c61715bef590c087c1fabe64c92ac92`.
- **Contracts touched (Ethereum):**
  - Core Hub `0xCca852Bc40e560adC3b1Cc58CA5b55638ce826c9`: pooled liquidity and share accounting per `assetId`; source of the deposit-gate deficit read (`getAssetDeficitRay`)
  - Main Spoke `0x94e7A5dCbE816e498b89aB752661904E2F56c485`: market entry point for supply/withdraw; hosts the USDC (reserveId 7, assetId 5) and WETH (reserveId 0, assetId 0) markets
  - Forex Spoke `0xD8B93635b8C6d0fF98CbE90b5988E3F2d1Cd9da1`: hosts the USDC (reserveId 1, assetId 5) market

  A spoke maps `reserveId` to `(underlying, hub, assetId)` and records user positions. Addresses match the `AAVE_V4_*` constants in `lib/grove-address-registry` (`src/Ethereum.sol`) at the pinned submodule commit and were verified against Etherscan on 2026-07-22. The facet itself is market-agnostic; governance whitelists markets via rate-limit keys and `maxSlippage`.
- **Audited/battle-tested status:** audit reports through 2026-04 (Blackthorn x2, Trail of Bits, ChainSecurity x3, Certora formal verification x4) in the [aave-v4 repo `audits/` directory](https://github.com/aave/aave-v4/tree/cfdf931c8c61715bef590c087c1fabe64c92ac92/audits).
- **Trust assumptions:**
  - All spoke/hub contracts are proxies upgradeable by Aave governance through a single AccessManager; a hostile upgrade can take the full supplied position. Exposure is bounded by position sizing and deposit rate limits, not facet code.
  - Socialized bad debt (hub deficit) never marks down the supplier share price; it surfaces as exit-liquidity shortfall for the last suppliers out.
  - Withdrawals are blocked by reserve pause (spoke) and by hub-side spoke deactivation or halt; a frozen reserve still allows withdrawal. The hub reverts rather than partially fills on insufficient liquidity.
  - The hub's reinvestment controller can deploy idle liquidity, reducing immediately withdrawable funds without touching positions.
  - The supply/withdraw path uses no price oracle; the share index is hub-internal accounting and not donation-manipulable (hub liquidity is tracked internally, not read from token balances).
- **House-constraint check:** initial underlyings are USDC (6 decimals) and WETH (18 decimals), both standard non-rebasing ERC-20; no oracle reliance on any leg; seeding requirements: n/a (no external share token exists, and the hub's internal share accounting has no inflation surface for a first depositor to exploit).

## Functions

### `deposit(address spoke, uint256 reserveId, uint256 amount)`

- **Role:** ALLOCATOR_ROLE
- **Value direction:** outbound (leaves custody)
- **Rate limit:** key constant `_LIMIT_DEPOSIT = keccak256("LIMIT_AAVE_V4_DEPOSIT")`, derivation `makeAddressUint256AddressUint16AddressKey(_LIMIT_DEPOSIT, spoke, reserveId, hub, assetId, underlying)` where `hub`, `assetId`, and `underlying` are read from `spoke.getReserve(reserveId)`; enforcing decrease of `amount`
- **Refill:** none, because this is the outbound leg; `withdraw` refills this key
- **Loss bounds:** per-market admin `maxSlippage` (1e18 precision, required nonzero: `AaveV4Facet/max-slippage-not-set`): the supplied-position delta measured via `getUserSuppliedAssets` before/after must satisfy `amountReceived >= amount * maxSlippage / 1e18`. Additionally the deposit is gated on `hub.getAssetDeficitRay(assetId) == 0` so capital never buys into unbacked debt at par
- **External calls:** `spoke.getReserve`, `hub.getAssetDeficitRay`, `spoke.getUserSuppliedAssets` (views); `spoke.supply(reserveId, amount, proxy)` via `doCall`; position is credited to the proxy (`onBehalfOf = proxy`, self-authorized, no position-manager onboarding). Approval `underlying -> spoke` is set for `amount` and reset to zero in the same call
- **Zero-amount semantics:** forbidden protocol-side: `Hub.add` requires `amount > 0` (`InvalidAmount()`, `Hub.sol` `_validateAdd`); the facet adds no zero-check of its own

### `withdraw(address spoke, uint256 reserveId, uint256 amount) returns (uint256 amountWithdrawn)`

- **Role:** ALLOCATOR_ROLE
- **Value direction:** returning (to proxy)
- **Rate limit:** key constant `_LIMIT_WITHDRAW = keccak256("LIMIT_AAVE_V4_WITHDRAW")`, derivation `makeAddressUint256Key(_LIMIT_WITHDRAW, spoke, reserveId)`; enforcing decrease of the measured `amountWithdrawn`
- **Refill:** `_tryIncreaseRateLimit(getDepositRateLimitKey(spoke, reserveId, reserve.hub, reserve.assetId, underlying), amountWithdrawn)`. Consequence of the reserve-derived key: a reserve remapped between deposit and withdraw still exits fine, but the refill silently no-ops against the unconfigured key
- **Loss bounds:** none needed: the transfer is amount-exact (the hub transfers the position-capped request in full or reverts with `InsufficientLiquidity`; there is no exchange-rate leg). `type(uint256).max` withdraws the full position. `amountWithdrawn` is measured as the proxy's underlying balance delta, not taken from return values
- **External calls:** `spoke.getReserve` (view, supplies the full reserve struct: `hub`, `assetId`, and `underlying` feed the refill key); `spoke.withdraw(reserveId, amount, proxy)` via `doCall`; receiver is the proxy
- **Zero-amount semantics:** forbidden protocol-side: `Hub.remove` requires `amount > 0` (`InvalidAmount()`, `Hub.sol` `_validateRemove`)

### `setMaxSlippage(address spoke, uint256 reserveId, uint256 maxSlippage)`

- **Role:** DEFAULT_ADMIN_ROLE
- **Value direction:** config
- **Rate limit:** none
- **Bounds:** `spoke` nonzero (`AaveV4Facet/spoke-zero-address`); no bound on `maxSlippage` itself, matching the other facets; `maxSlippage = 0` is allowed and disables deposits for the market (`deposit` requires it nonzero)
- **External calls:** none
- **Zero-amount semantics:** n/a

### Views: `getDepositRateLimitKey(address spoke, uint256 reserveId, address hub, uint16 assetId, address underlying)`, `getWithdrawRateLimitKey(address spoke, uint256 reserveId)`, `getMaxSlippage(address spoke, uint256 reserveId)`

- **Role:** none (view/pure)
- **Value direction:** none
- Return the two key derivations above and the configured per-market tolerance (zero when unset)

## Fund-exit map

| # | Path | Destination | Bounded by |
|---|------|-------------|------------|
| 1 | `doCall` `spoke.supply` | underlying moves proxy -> hub; proxy credited a non-tokenized supplied position on the spoke | `LIMIT_AAVE_V4_DEPOSIT`, per `(spoke, reserveId, hub, assetId, underlying)`, plus the `maxSlippage` floor on the credited position |

No other path moves value out of custody. `withdraw` and the views only return value or read state; `setMaxSlippage` is config.

## Storage & constructor

- **ERC-7201 storage fields:** `mapping(address spoke => mapping(uint256 reserveId => uint256 maxSlippage)) maxSlippages` (admin parameter only), namespace `sky.pau.storage.AaveV4Facet.v1`, slot constant `0xfaa4b673fef63a93f9acc6a7f61e1b14d1e71d39344cfddfb7b4e936fd166b00`
- **Immutables:** none
- **Auxiliary module:** none

## Standing approvals & declared exceptions

None. The deposit approval to the spoke is set and reset to zero within the same `deposit` call; outside a transaction no external contract holds an allowance on proxy funds.

## Dependencies

None: no new `lib/` submodule. The facet adds two `make*Key` free functions to `src/libraries/RateLimitHelpers.sol` (`makeAddressUint256Key`, `makeAddressUint256AddressUint16AddressKey`), additions-only per G-2, needed because Aave V4 market identifiers mix addresses with a `uint256` reserve id and a `uint16` asset id.

## Attack surface (drives T-4 required tests)

- **Mutable third-party reads feeding keys/checks:** `spoke.getReserve(reserveId)` supplies `underlying`, `hub`, and `assetId`; all three feed the deposit key, and `hub`/`assetId` additionally feed the deficit gate. A spoke remapping a reserve must not spend a budget configured for the original mapping: embedding every reserve-derived value in the key guarantees the remapped market has no configured deposit limit. Requires a `test_attack_reserveRemapped_*` style test asserting deposits revert after a remap of all three components until governance reconfigures.
- **Async/multi-step state a rogue allocator could grief:** none; both operations settle synchronously in one transaction and hold no pending state between calls.
- **Value-manipulation surface (donation/inflation/rounding):** supply crediting rounds in the hub's share math; bounded by the `maxSlippage` floor on the measured position delta. The share index is not manipulable by donation (hub tracks liquidity internally). Deficit-carrying assets cannot be bought into (deposit gate). Withdrawals have no manipulation surface: amount-exact or revert.

## Operational requirements

Per market, before the first deposit, in this order:

1. `setMaxSlippage(spoke, reserveId, maxSlippage)`: nonzero; `0.9999e18` is the standard tolerance (values at or above 1e18 revert every deposit once the reserve accrues interest, and tighter values risk spurious reverts on low-decimal assets once the share price exceeds 1:1).
2. Configure `LIMIT_AAVE_V4_DEPOSIT` keyed `(spoke, reserveId, hub, assetId, underlying)`.
3. Configure `LIMIT_AAVE_V4_WITHDRAW` keyed `(spoke, reserveId)`; this key alone gates withdrawal (the deposit key is refilled opportunistically and zeroing it does not pause withdrawals).

No seeding. Monitoring (detailed in `docs/AAVEV4_INTEGRATION.md`): proxy upgrades on spoke/hub and their admins (largest single risk; unannounced upgrade is an exit trigger), hub deficit per asset (nonzero blocks deposits and signals bad debt), hub liquidity vs. position size (exit-liquidity headroom), spoke/hub control states (pause, deactivation, halt), and reserve underlying remaps.
