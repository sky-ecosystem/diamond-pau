// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Ownable }      from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { Ownable2Step } from "../../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";

import {
    BeforeSwapDelta,
    toBeforeSwapDelta
} from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";

import {
    ModifyLiquidityParams,
    SwapParams
} from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolOperation.sol";

import { IHooks }       from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

interface IERC20Like {

    // NOTE: Mutating functions purposely do not declare return values so that non-conformant
    //       tokens (e.g. USDT) can be used in fork tests.

    function approve(address spender, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function transfer(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external;

}

/**
 * @title  MockDualPoolHook
 * @notice Test double for the DualPoolHook that the DualPoolFacet integrates with. Implements
 *         the hook's external surface with faithful semantics so the facet can be exercised
 *         end to end on a mainnet fork against the real PoolManager, Universal Router, and
 *         Permit2:
 *
 *         - Share-based LP accounting: bootstrap mints sqrt(amount0 * amount1) shares subject to
 *           the real hook's 100 * 10**decimalsOffset floor, conversions apply the same
 *           shares * (total + 1) / (supply + 10**decimalsOffset) virtual-share formula with the
 *           offset derived from the pair's decimals, deposits round up and withdrawals round down,
 *           and shares are pool-scoped and non-transferable.
 *         - Deposit lock: each deposit locks the depositor's whole position in that pool for
 *           minDepositBlocks; removeLiquidity reverts while locked.
 *         - Swaps: a 1:1 stable custom curve via beforeSwap return delta (exact input only),
 *           charging the pool's static fee to hook reserves, so real Universal Router V4_SWAP
 *           commands execute against the mock's liquidity. Swaps revert when the pool is not
 *           live; removeLiquidity keeps working while paused.
 *         - Direct Uniswap V4 liquidity provision is blocked (beforeAddLiquidity and
 *           beforeRemoveLiquidity revert), mirroring the real hook's owner-only LP model.
 *         - Vault approval levers (refreshVaultApproval, emergencyRevokeVault).
 *
 *         The contract must be etched at an address whose flag bits are
 *         BEFORE_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY | BEFORE_SWAP |
 *         BEFORE_SWAP_RETURNS_DELTA (0x0a88).
 *
 *         NOT a faithful double. The divergences below are deliberate, since reproducing them would
 *         mean reimplementing the hook, and every one of them is instead covered against the real
 *         deployed hook in test/mainnet-fork/DualPoolLive.t.sol. Do not read a passing test here
 *         as evidence about any of these:
 *
 *         - Swap pricing. The real hook declares beforeSwap/afterSwap without a return delta and
 *           deploys JIT liquidity across up to 8 buckets, so swaps walk a real concentrated
 *           liquidity curve and have price impact. This mock consumes the whole swap through a
 *           beforeSwap return delta on a flat 1:1 curve less the static fee, so price impact,
 *           the interaction between curve slippage and the facet's amountOutMin floor, and the
 *           gas cost of the JIT cycle are all absent. The declared flags differ accordingly, so
 *           this address could not host the real hook.
 *         - Withdrawal path. The real removeLiquidity routes through poolManager.unlock and
 *           redeems the hook's ERC-6909 claims in the callback before the withdraw math, and may
 *           pull from an ERC-4626 vault. This mock transfers directly from its own reserves, so
 *           there is no unlock context and no vault interaction: a paused or illiquid vault
 *           impairing an exit cannot be observed here.
 *         - Vault custody and validation. The real hook parks idle inventory in ERC-4626 vaults,
 *           requires each vault's asset() to match its currency, and rejects fee-charging vaults.
 *           This mock holds tokens directly and accepts any address, including an EOA, so vault
 *           share-price movement and vault misconfiguration are both invisible.
 *         - Direct initialization. The real hook reverts beforeInitialize, forcing pool creation
 *           through initializePool. This mock does not implement that callback.
 */
contract MockDualPoolHook is Ownable2Step {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct LiquidityBucket {
        int24  tickLower;
        int24  tickUpper;
        uint16 weightBps;
    }

    struct PoolConfig {
        uint160           sqrtPriceX96;
        LiquidityBucket[] distribution;
        bool              allowExternalDeposits;
        address           vault0;
        address           vault1;
        uint64            minDepositBlocks;
    }

    struct PoolState {
        bool    initialized;
        bool    live;
        bool    externalDepositsEnabled;
        uint64  minDepositBlocks;
        uint8   decimalsOffset;
        address vault0;
        address vault1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
    }

    /**********************************************************************************************/
    /*** Errors                                                                                 ***/
    /**********************************************************************************************/

    error LiquidityNotAllowed();

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    IPoolManager public immutable poolManager;

    mapping (bytes32 poolId => PoolState state) internal _pools;

    mapping (bytes32 poolId => LiquidityBucket[] buckets) internal _distributions;

    mapping (bytes32 poolId => mapping (address user => uint256 shares)) internal _shares;

    mapping (bytes32 poolId => mapping (address user => uint256 blockNumber)) internal _lastDepositBlock;

    /**********************************************************************************************/
    /*** Constructor/Modifiers                                                                  ***/
    /**********************************************************************************************/

    constructor(IPoolManager poolManager_, address owner_) Ownable(owner_) {
        poolManager = poolManager_;
    }

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "MockDualPoolHook/not-pool-manager");
        _;
    }

    /**********************************************************************************************/
    /*** Owner Functions                                                                        ***/
    /**********************************************************************************************/

    function initializePool(PoolKey calldata key, PoolConfig calldata config)
        external
        onlyOwner
        returns (int24 tick)
    {
        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        require(!pool.initialized, "MockDualPoolHook/already-initialized");

        tick = poolManager.initialize(key, config.sqrtPriceX96);

        pool.initialized             = true;
        pool.externalDepositsEnabled = config.allowExternalDeposits;
        pool.minDepositBlocks        = config.minDepositBlocks;
        pool.vault0                  = config.vault0;
        pool.vault1                  = config.vault1;

        // Derived once at initialization and immutable thereafter, as on the real hook, so the
        // conversion math reads a stable value for the pool's lifetime.
        pool.decimalsOffset = _deriveDecimalsOffset(key.currency0, key.currency1);

        _setDistribution(poolId, config.distribution);

        _refreshVaultApproval(key.currency0, config.vault0);
        _refreshVaultApproval(key.currency1, config.vault1);
    }

    function bootstrap(PoolKey calldata key, uint256 amount0, uint256 amount1)
        external
        onlyOwner
        returns (uint256 shares)
    {
        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        require(pool.initialized,      "MockDualPoolHook/not-initialized");
        require(pool.totalShares == 0, "MockDualPoolHook/already-bootstrapped");

        require(amount0 != 0 && amount1 != 0, "MockDualPoolHook/insufficient-bootstrap");

        shares = _sqrt(amount0 * amount1);

        // The real hook floors the genesis mint at 100 * 10**decimalsOffset so the virtual-share
        // inflation defense is meaningful; below that the round trip's drift exceeds ~1%.
        require(
            shares >= 100 * 10 ** uint256(pool.decimalsOffset),
            "MockDualPoolHook/bootstrap-too-small"
        );

        IERC20Like(Currency.unwrap(key.currency0)).transferFrom(msg.sender, address(this), amount0);
        IERC20Like(Currency.unwrap(key.currency1)).transferFrom(msg.sender, address(this), amount1);

        pool.reserve0    = amount0;
        pool.reserve1    = amount1;
        pool.totalShares = shares;
        pool.live        = true;

        _shares[poolId][msg.sender] = shares;

        _lastDepositBlock[poolId][msg.sender] = block.number;
    }

    function setDistribution(PoolKey calldata key, LiquidityBucket[] calldata buckets)
        external
        onlyOwner
    {
        _setDistribution(_toPoolId(key), buckets);
    }

    function setExternalDeposits(PoolKey calldata key, bool enabled) external onlyOwner {
        _pools[_toPoolId(key)].externalDepositsEnabled = enabled;
    }

    function setPoolLive(PoolKey calldata key, bool live) external onlyOwner {
        _pools[_toPoolId(key)].live = live;
    }

    /// @dev The real hook resolves the vault through a (poolId, currency) mapping, so a currency
    ///      outside the pair resolves to address(0) and the call is a silent no-op. Selecting
    ///      vault1 for anything that is not currency0 would instead approve vault1 against an
    ///      arbitrary token.
    function refreshVaultApproval(PoolKey calldata key, Currency currency) external onlyOwner {
        PoolState storage pool = _pools[_toPoolId(key)];

        address vault;

        if      (currency == key.currency0) vault = pool.vault0;
        else if (currency == key.currency1) vault = pool.vault1;

        _refreshVaultApproval(currency, vault);
    }

    function emergencyRevokeVault(PoolKey calldata key) external onlyOwner {
        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        pool.live                    = false;
        pool.externalDepositsEnabled = false;

        if (pool.vault0 != address(0)) IERC20Like(Currency.unwrap(key.currency0)).approve(pool.vault0, 0);
        if (pool.vault1 != address(0)) IERC20Like(Currency.unwrap(key.currency1)).approve(pool.vault1, 0);
    }

    /**********************************************************************************************/
    /*** LP Functions                                                                           ***/
    /**********************************************************************************************/

    function addLiquidity(
        PoolKey calldata key,
        uint256 sharesToMint,
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint256 deadline
    )
        external
        returns (uint256 amount0, uint256 amount1)
    {
        require(block.timestamp <= deadline, "MockDualPoolHook/past-deadline");

        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        require(pool.totalShares > 0, "MockDualPoolHook/not-bootstrapped");

        require(
            msg.sender == owner() || pool.externalDepositsEnabled,
            "MockDualPoolHook/deposits-not-allowed"
        );

        ( amount0, amount1 ) = _convertToAmounts(pool, sharesToMint, true);

        require(amount0 <= maxAmount0 && amount1 <= maxAmount1, "MockDualPoolHook/slippage-exceeded");

        IERC20Like(Currency.unwrap(key.currency0)).transferFrom(msg.sender, address(this), amount0);
        IERC20Like(Currency.unwrap(key.currency1)).transferFrom(msg.sender, address(this), amount1);

        pool.reserve0    += amount0;
        pool.reserve1    += amount1;
        pool.totalShares += sharesToMint;

        _shares[poolId][msg.sender] += sharesToMint;

        _lastDepositBlock[poolId][msg.sender] = block.number;
    }

    /// @dev Deliberately callable while the pool is paused: exits stay open under pause, like
    ///      the real hook.
    function removeLiquidity(
        PoolKey calldata key,
        uint256 sharesToBurn,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    )
        external
        returns (uint256 amount0, uint256 amount1)
    {
        require(block.timestamp <= deadline, "MockDualPoolHook/past-deadline");

        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        require(
            block.number >= _lastDepositBlock[poolId][msg.sender] + pool.minDepositBlocks,
            "MockDualPoolHook/deposit-locked"
        );

        ( amount0, amount1 ) = _convertToAmounts(pool, sharesToBurn, false);

        require(amount0 >= minAmount0 && amount1 >= minAmount1, "MockDualPoolHook/slippage-exceeded");

        _shares[poolId][msg.sender] -= sharesToBurn;

        pool.reserve0    -= amount0;
        pool.reserve1    -= amount1;
        pool.totalShares -= sharesToBurn;

        IERC20Like(Currency.unwrap(key.currency0)).transfer(msg.sender, amount0);
        IERC20Like(Currency.unwrap(key.currency1)).transfer(msg.sender, amount1);
    }

    /**********************************************************************************************/
    /*** View Functions                                                                         ***/
    /**********************************************************************************************/

    function decimalsOffset(bytes32 poolId) external view returns (uint8) {
        return _pools[poolId].decimalsOffset;
    }

    function externalDepositsEnabled(bytes32 poolId) external view returns (bool) {
        return _pools[poolId].externalDepositsEnabled;
    }

    function totalShares(bytes32 poolId) external view returns (uint256) {
        return _pools[poolId].totalShares;
    }

    function getPoolState(bytes32 poolId) external view returns (PoolState memory state) {
        return _pools[poolId];
    }

    function minDepositBlocks(bytes32 poolId) external view returns (uint64) {
        return _pools[poolId].minDepositBlocks;
    }

    function previewDeposit(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _convertToAmounts(_pools[_toPoolId(key)], shares, true);
    }

    function previewWithdraw(PoolKey calldata key, uint256 shares)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _convertToAmounts(_pools[_toPoolId(key)], shares, false);
    }

    function sharesOf(PoolKey calldata key, address user) external view returns (uint256) {
        return _shares[_toPoolId(key)][user];
    }

    /**********************************************************************************************/
    /*** Uniswap V4 Hook Callbacks                                                              ***/
    /**********************************************************************************************/

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        revert LiquidityNotAllowed();
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        revert LiquidityNotAllowed();
    }

    /// @notice Exact-input 1:1 stable swap against hook reserves, charging the pool's static
    ///         fee. Consumes the whole swap via return delta so the core AMM math is skipped.
    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bytes32 poolId = _toPoolId(key);

        PoolState storage pool = _pools[poolId];

        require(pool.live,                  "MockDualPoolHook/pool-not-live");
        require(params.amountSpecified < 0, "MockDualPoolHook/exact-input-only");

        uint256 amountIn = uint256(-params.amountSpecified);

        ( Currency currencyIn, Currency currencyOut ) = params.zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);

        // 1:1 stable price across decimal scales, less the pool's static fee (fee in pips).
        uint256 amountOut = amountIn
            * (10 ** IERC20Like(Currency.unwrap(currencyOut)).decimals())
            / (10 ** IERC20Like(Currency.unwrap(currencyIn)).decimals());

        amountOut -= amountOut * key.fee / 1e6;

        require(
            amountOut <= (params.zeroForOne ? pool.reserve1 : pool.reserve0),
            "MockDualPoolHook/insufficient-reserves"
        );

        // Take the input into hook reserves and pay the output from them; the return delta
        // credits both against the swapper, whom the router settles via Permit2.
        poolManager.take(currencyIn, address(this), amountIn);

        poolManager.sync(currencyOut);
        IERC20Like(Currency.unwrap(currencyOut)).transfer(address(poolManager), amountOut);
        poolManager.settle();

        if (params.zeroForOne) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        return (
            IHooks.beforeSwap.selector,
            toBeforeSwapDelta(int128(-params.amountSpecified), -int128(uint128(amountOut))),
            0
        );
    }

    /**********************************************************************************************/
    /*** Internal Functions                                                                     ***/
    /**********************************************************************************************/

    /// @dev Mirrors MultiAssetShareMath.convertToAmounts on the real hook:
    ///
    ///          amount = shares * (total + 1) / (supply + 10**decimalsOffset)
    ///
    ///      The virtual-share offset and the +1 on each balance are the hook's inflation defense,
    ///      and they make the deposit/withdraw round trip lossy by design. Deposits round up and
    ///      withdrawals round down, so rounding always favours the pool. Reverts rather than
    ///      returning zero on an unbootstrapped pool, matching Shares.convertToAmounts.
    function _convertToAmounts(PoolState storage pool, uint256 shares, bool roundUp)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 supply = pool.totalShares;

        require(supply != 0, "MockDualPoolHook/vault-not-bootstrapped");

        uint256 effSupply = supply + 10 ** uint256(pool.decimalsOffset);

        if (roundUp) {
            amount0 = _mulDivUp(shares, pool.reserve0 + 1, effSupply);
            amount1 = _mulDivUp(shares, pool.reserve1 + 1, effSupply);
        } else {
            amount0 = shares * (pool.reserve0 + 1) / effSupply;
            amount1 = shares * (pool.reserve1 + 1) / effSupply;
        }
    }

    /// @dev Derives the pool's virtual-share offset the way the real hook does: the average of the
    ///      two currencies' decimals less a 6-decimal margin, clamped to [6, 12]. A 6/6 pair (e.g.
    ///      USDC/USDT) lands on 6, an 18/18 pair on 12.
    function _deriveDecimalsOffset(Currency currency0, Currency currency1)
        internal
        view
        returns (uint8)
    {
        uint256 average = (
            uint256(_tokenDecimals(currency0)) + uint256(_tokenDecimals(currency1))
        ) / 2;

        uint256 raw = average > 6 ? average - 6 : 0;

        if (raw < 6)  raw = 6;
        if (raw > 12) raw = 12;

        return uint8(raw);
    }

    function _mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return x * y == 0 ? 0 : (x * y - 1) / d + 1;
    }

    function _tokenDecimals(Currency currency) internal view returns (uint8) {
        try IERC20Like(Currency.unwrap(currency)).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    function _refreshVaultApproval(Currency currency, address vault) internal {
        if (vault != address(0)) IERC20Like(Currency.unwrap(currency)).approve(vault, type(uint256).max);
    }

    function _setDistribution(bytes32 poolId, LiquidityBucket[] calldata buckets) internal {
        uint256 totalWeight;

        for (uint256 i = 0; i < buckets.length; i++) {
            totalWeight += buckets[i].weightBps;
        }

        require(totalWeight == 10_000, "MockDualPoolHook/invalid-distribution");

        delete _distributions[poolId];

        for (uint256 i = 0; i < buckets.length; i++) {
            _distributions[poolId].push(buckets[i]);
        }
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;

        y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _toPoolId(PoolKey calldata key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }

}
