// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Currency } from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IDualPoolFacet
 * @notice PAU facet for operating an ALMProxy-owned DualPoolHook deployment and allocating into
 *         its pools. DualPool pools are Uniswap V4 pools whose liquidity is provisioned
 *         just-in-time by the hook from hook-held (and ERC-4626 rehypothecated) reserves; LP
 *         entry and exit go through the hook's own share-based functions rather than the
 *         Uniswap V4 PositionManager.
 *
 *         Role model:
 *         - DEFAULT_ADMIN_ROLE (governance): pool lifecycle, configuration, resume, hook
 *           ownership handshake, and the once-per-pool genesis bootstrap.
 *         - FREEZER_ROLE (incident response): strictly de-escalatory pause and vault revocation.
 *         - ALLOCATOR_ROLE (assumed compromisable): rate-limited deposit, withdraw and swap,
 *           all value-floored by governance-set max slippage and currency price ratio.
 *
 *         The hook has no poolId to PoolKey registry, so interactive functions take the full
 *         PoolKey from calldata and derive poolId as keccak256(abi.encode(key)). All facet
 *         config and rate limit keys bind to the derived id and key.hooks must match the
 *         facet's immutable hook, so a fabricated key can only reach a disabled configuration.
 */
interface IDualPoolFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Single JIT liquidity range with its capital weight. Mirrors the DualPoolHook
     *         LiquidityBucket struct for ABI compatibility.
     * @param  tickLower Lower tick of the range.
     * @param  tickUpper Upper tick of the range.
     * @param  weightBps Fraction of total capital allocated to this range, in basis points.
     *                   All weights across a pool's distribution sum to 10_000.
     */
    struct LiquidityBucket {
        int24  tickLower;
        int24  tickUpper;
        uint16 weightBps;
    }

    /**
     * @notice Pool creation configuration. Mirrors the DualPoolHook PoolConfig struct for ABI
     *         compatibility.
     * @param  sqrtPriceX96          Initial pool price.
     * @param  distribution          JIT liquidity distribution (weights sum to 10_000).
     * @param  allowExternalDeposits Whether non-owner LP deposits are permitted on the hook.
     * @param  vault0                ERC-4626 vault for currency0 reserves (zero to disable).
     * @param  vault1                ERC-4626 vault for currency1 reserves (zero to disable).
     * @param  minDepositBlocks      Blocks a depositor's position stays locked after a deposit.
     */
    struct PoolConfig {
        uint160           sqrtPriceX96;
        LiquidityBucket[] distribution;
        bool              allowExternalDeposits;
        address           vault0;
        address           vault1;
        uint64            minDepositBlocks;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted on the genesis deposit that flips a pool live.
     * @param  poolId  DualPool pool identifier (keccak256(abi.encode(poolKey))).
     * @param  shares  Shares minted to the ALMProxy.
     * @param  amount0 Amount of currency0 pulled from the ALMProxy.
     * @param  amount1 Amount of currency1 pulled from the ALMProxy.
     */
    event DualPoolBootstrap(bytes32 indexed poolId, uint256 shares, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted on an allocator deposit.
     * @param  poolId  DualPool pool identifier.
     * @param  shares  Shares minted to the ALMProxy.
     * @param  amount0 Measured amount of currency0 spent by the ALMProxy.
     * @param  amount1 Measured amount of currency1 spent by the ALMProxy.
     */
    event DualPoolDeposit(bytes32 indexed poolId, uint256 shares, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when the JIT liquidity distribution is replaced through the facet.
     * @param  poolId DualPool pool identifier.
     */
    event DualPoolDistributionSet(bytes32 indexed poolId);

    /**
     * @notice Emitted when third-party LP access is toggled through the facet.
     * @param  poolId  DualPool pool identifier.
     * @param  enabled Whether non-owner deposits are permitted on the hook.
     */
    event DualPoolExternalDepositsSet(bytes32 indexed poolId, bool enabled);

    /// @notice Emitted when the facet accepts hook ownership on behalf of the ALMProxy.
    event DualPoolHookOwnershipAccepted();

    /**
     * @notice Emitted when hook ownership transfer is initiated to a new owner.
     * @param  newOwner Pending owner (Ownable2Step; ineffective until accepted).
     */
    event DualPoolHookOwnershipTransferInitiated(address indexed newOwner);

    /**
     * @notice Emitted when pool liveness is toggled through the facet (pause or resume).
     * @param  poolId DualPool pool identifier.
     * @param  live   True on resume, false on pause.
     */
    event DualPoolLivenessSet(bytes32 indexed poolId, bool live);

    /**
     * @notice Emitted when the max slippage for a pool is updated.
     * @param  poolId      DualPool pool identifier.
     * @param  maxSlippage New max slippage in 1e18 precision (1e18 = no slippage). Zero disables.
     */
    event DualPoolMaxSlippageSet(bytes32 indexed poolId, uint256 maxSlippage);

    /**
     * @notice Emitted when a pool is created on the hook through the facet.
     * @param  poolId DualPool pool identifier.
     * @param  tick   Initial tick assigned by the PoolManager.
     */
    event DualPoolPoolInitialized(bytes32 indexed poolId, int24 tick);

    /**
     * @notice Emitted when the currency price ratio for a pool is updated.
     * @param  poolId     DualPool pool identifier.
     * @param  priceRatio Value of one whole unit of currency1 in whole units of currency0, in 1e18
     *                    precision (1e18 = parity). Zero disables allocator operations.
     */
    event DualPoolPriceRatioSet(bytes32 indexed poolId, uint256 priceRatio);

    /**
     * @notice Emitted on an allocator swap through a DualPool pool.
     * @param  poolId    DualPool pool identifier.
     * @param  tokenIn   Address of the input token.
     * @param  tokenOut  Address of the output token.
     * @param  amountIn  Amount of input tokens spent.
     * @param  amountOut Measured amount of output tokens received by the ALMProxy.
     */
    event DualPoolSwap(
        bytes32 indexed poolId,
        address indexed tokenIn,
        address         tokenOut,
        uint256         amountIn,
        uint256         amountOut
    );

    /**
     * @notice Emitted when a vault allowance is re-armed through the facet.
     * @param  poolId   DualPool pool identifier.
     * @param  currency Currency side that was refreshed.
     */
    event DualPoolVaultApprovalRefreshed(bytes32 indexed poolId, address currency);

    /**
     * @notice Emitted when the freezer triggers the hook's atomic vault revocation.
     * @param  poolId DualPool pool identifier.
     */
    event DualPoolVaultRevoked(bytes32 indexed poolId);

    /**
     * @notice Emitted on an allocator withdrawal.
     * @param  poolId  DualPool pool identifier.
     * @param  shares  Shares burned from the ALMProxy position.
     * @param  amount0 Measured amount of currency0 received by the ALMProxy.
     * @param  amount1 Measured amount of currency1 received by the ALMProxy.
     */
    event DualPoolWithdraw(bytes32 indexed poolId, uint256 shares, uint256 amount0, uint256 amount1);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /// @notice Accepts hook ownership on behalf of the ALMProxy (Ownable2Step handshake).
    function acceptHookOwnership() external;

    /**
     * @notice Genesis deposit: seeds the pool from ALMProxy funds and flips it live. Admin-gated
     *         and not rate limited: the amounts are fixed in the governance proposal that
     *         schedules the call, and rate limits may not be seeded yet.
     * @param  key     PoolKey of the pool to bootstrap.
     * @param  amount0 Amount of currency0 to deposit.
     * @param  amount1 Amount of currency1 to deposit.
     */
    function bootstrap(PoolKey calldata key, uint256 amount0, uint256 amount1) external;

    /**
     * @notice Deposits into a pool, minting pool shares to the ALMProxy.
     * @param  key          PoolKey of the pool to deposit into.
     * @param  sharesToMint Shares to mint; required amounts follow the pool's current ratio. Must
     *                      be non-zero: a deposit that mints nothing still re-arms the hook's
     *                      deposit lock, which would gate the ALMProxy's next withdrawal.
     * @param  amount0Max   Maximum amount of currency0 the ALMProxy may spend.
     * @param  amount1Max   Maximum amount of currency1 the ALMProxy may spend.
     */
    function deposit(PoolKey calldata key, uint256 sharesToMint, uint128 amount0Max, uint128 amount1Max)
        external;

    /**
     * @notice Triggers the hook's atomic vault incident lever: pause, close external deposits,
     *         zero vault allowances, best-effort drain vault assets back into the hook.
     * @param  key PoolKey of the pool whose vault exposure to revoke.
     */
    function emergencyRevokeVault(PoolKey calldata key) external;

    /**
     * @notice Creates a pool on the hook via the ALMProxy (the hook owner).
     * @param  key    PoolKey of the pool; key.hooks must be this facet's hook.
     * @param  config Hook pool configuration (price, distribution, gate, vaults, deposit lock).
     */
    function initializePool(PoolKey calldata key, PoolConfig calldata config) external;

    /**
     * @notice Pauses a pool: swaps revert, LP exits stay open.
     * @param  key PoolKey of the pool to pause.
     */
    function pausePool(PoolKey calldata key) external;

    /**
     * @notice Re-arms a vault allowance after an incident is resolved.
     * @param  key      PoolKey of the pool whose vault approval to refresh.
     * @param  currency Currency side to refresh.
     */
    function refreshVaultApproval(PoolKey calldata key, Currency currency) external;

    /**
     * @notice Resumes a paused pool. Pausing is the freezer's lever; resuming is admin-only so
     *         the freezer path stays strictly de-escalatory.
     * @param  key PoolKey of the pool to resume.
     */
    function resumePool(PoolKey calldata key) external;

    /**
     * @notice Replaces the JIT liquidity distribution for a pool.
     * @param  key     PoolKey of the pool to update.
     * @param  buckets New bucket set (weights must sum to 10_000 on the hook side).
     */
    function setDistribution(PoolKey calldata key, LiquidityBucket[] calldata buckets) external;

    /**
     * @notice Toggles third-party LP deposits on the hook.
     * @param  key     PoolKey of the pool to configure.
     * @param  enabled True to permit non-owner deposits.
     */
    function setExternalDeposits(PoolKey calldata key, bool enabled) external;

    /**
     * @notice Sets the max slippage for a DualPool pool. Allocator operations additionally require
     *         a non-zero price ratio; see {setPriceRatio}.
     *
     *         Values above 1e18 are rejected: they would demand a better-than-perfect round trip on
     *         every path, and because removeLiquidity is the only exit from a non-transferable share
     *         position, an unsatisfiable withdraw floor would strand the position.
     *
     *         Note that deposit needs a value strictly below 1e18. Its round-trip floor compares
     *         what the shares redeem for against what was paid, and the hook rounds the deposit up
     *         while rounding the redemption down, so the round trip is lossy by design. At exactly
     *         1e18 withdraw and swap still work but deposit always reverts.
     * @param  poolId      DualPool pool identifier (keccak256(abi.encode(poolKey))).
     * @param  maxSlippage Max slippage in 1e18 precision (1e18 = no slippage), at most 1e18. Zero
     *                     disables allocator operations.
     */
    function setMaxSlippage(bytes32 poolId, uint256 maxSlippage) external;

    /**
     * @notice Sets the relative price of the pool's two currencies, which denominates the deposit,
     *         withdraw and swap value floors. Non-zero, together with a non-zero max slippage,
     *         enables allocator operations.
     *
     *         The floors compare the value of what the ALMProxy pays against the value of what it
     *         receives, and this ratio is what makes those two amounts comparable when they are in
     *         different currencies. Set it to 1e18 for a pegged pair, where one unit of currency1
     *         is worth one unit of currency0. For any other pair a stale ratio weakens all three
     *         floors in proportion to how far it has drifted from the true price, so a non-pegged
     *         pool requires governance to keep this value current.
     * @param  poolId     DualPool pool identifier (keccak256(abi.encode(poolKey))).
     * @param  priceRatio Value of one whole unit of currency1 in whole units of currency0, in 1e18
     *                    precision (1e18 = parity). Zero disables allocator operations.
     */
    function setPriceRatio(bytes32 poolId, uint256 priceRatio) external;

    /**
     * @notice Swaps tokens through a DualPool pool via the Uniswap V4 Universal Router
     *         (exact input).
     * @param  key          PoolKey of the pool to swap through.
     * @param  tokenIn      Address of the input token; must be one of the pool's currencies.
     * @param  amountIn     Amount of input tokens to swap.
     * @param  amountOutMin Minimum output tokens to receive.
     */
    function swap(PoolKey calldata key, address tokenIn, uint128 amountIn, uint128 amountOutMin)
        external;

    /**
     * @notice Initiates hook ownership transfer away from the ALMProxy (offboarding).
     * @param  newOwner Proposed new owner; must accept to complete.
     */
    function transferHookOwnership(address newOwner) external;

    /**
     * @notice Withdraws from a pool, burning ALMProxy-held pool shares.
     * @param  key          PoolKey of the pool to withdraw from.
     * @param  sharesToBurn Shares to burn.
     * @param  amount0Min   Minimum amount of currency0 the ALMProxy will accept.
     * @param  amount1Min   Minimum amount of currency1 the ALMProxy will accept.
     */
    function withdraw(PoolKey calldata key, uint256 sharesToBurn, uint128 amount0Min, uint128 amount1Min)
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Role identifier for incident response: may pause pools and revoke vault
    ///         exposure, nothing else.
    function FREEZER_ROLE() external pure returns (bytes32);

    /// @notice Address of the ALMProxy-owned DualPoolHook deployment this facet operates
    ///         (immutable).
    function hook() external view returns (address);

    /// @notice Address of the Permit2 contract used for swap approvals (immutable).
    function permit2() external view returns (address);

    /// @notice Address of the Uniswap V4 Universal Router contract (immutable).
    function router() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the derived aggregate (both-currency, normalized) deposit rate limit key
     *         for a pool.
     * @param  poolId DualPool pool identifier.
     * @return key    Derived rate limit key.
     */
    function getAggregateDepositRateLimitKey(bytes32 poolId) external pure returns (bytes32 key);

    /**
     * @notice Returns the derived aggregate (both-currency, normalized) withdraw rate limit key
     *         for a pool.
     * @param  poolId DualPool pool identifier.
     * @return key    Derived rate limit key.
     */
    function getAggregateWithdrawRateLimitKey(bytes32 poolId) external pure returns (bytes32 key);

    /**
     * @notice Returns the derived deposit rate limit key for a pool and token.
     * @param  poolId DualPool pool identifier.
     * @param  token  Address of the token being deposited.
     * @return key    Derived rate limit key.
     */
    function getAssetDepositRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the derived withdraw rate limit key for a pool and token.
     * @param  poolId DualPool pool identifier.
     * @param  token  Address of the token being withdrawn.
     * @return key    Derived rate limit key.
     */
    function getAssetWithdrawRateLimitKey(bytes32 poolId, address token)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the configured max slippage for a DualPool pool.
     * @param  poolId      DualPool pool identifier.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set (disabled).
     */
    function getMaxSlippage(bytes32 poolId) external view returns (uint256 maxSlippage);

    /**
     * @notice Returns the configured currency price ratio for a DualPool pool.
     * @param  poolId     DualPool pool identifier.
     * @return priceRatio Value of one whole unit of currency1 in whole units of currency0, in 1e18
     *                    precision. Zero means not set (disabled).
     */
    function getPriceRatio(bytes32 poolId) external view returns (uint256 priceRatio);

    /**
     * @notice Returns the ALMProxy's share balance in a pool.
     * @param  key    PoolKey of the pool.
     * @return shares ALMProxy-held pool shares.
     */
    function getShares(PoolKey calldata key) external view returns (uint256 shares);

    /**
     * @notice Returns the derived swap rate limit key for a pool and token.
     * @param  poolId DualPool pool identifier.
     * @param  token  Address of the token being swapped in.
     * @return key    Derived rate limit key.
     */
    function getSwapRateLimitKey(bytes32 poolId, address token) external pure returns (bytes32 key);

}
