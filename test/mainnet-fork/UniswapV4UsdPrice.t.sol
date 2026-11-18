// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { Math } from "../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { Currency } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/Currency.sol";
import { PoolKey }  from "../../lib/uniswap-v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { FullMath } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/libraries/FullMath.sol";
import { TickMath } from "../../lib/uniswap-v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { IHooks }   from "../../lib/uniswap-v4-periphery/lib/v4-core/src/interfaces/IHooks.sol";

import { Actions } from "../../lib/uniswap-v4-periphery/src/libraries/Actions.sol";

import {
    IERC20Like,
    IPermit2Like,
    IPositionManagerLike,
    UniswapV4_TestBase
} from "./UniswapV4.t.sol";

interface IERC4626Like {

    function asset() external view returns (address);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

}

interface IPositionManagerPoolLike {

    function initializePool(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24);

    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external;

}

/**
 * @dev Tests for the USD-denominated validations of the UniswapV4Facet, which allow it to support
 *      pools of USD-pegged tokens and/or ERC4626 vaults with USD-pegged underlying assets:
 *      - USD price tick limits, on top of the raw tick limits, when minting/increasing positions.
 *      - Aggregate deposit/withdraw rate limits charged in USD value.
 *      - Swap max slippage validated in USD value.
 */
abstract contract UniswapV4_UsdPrice_TestBase is UniswapV4_TestBase {

    uint256 internal constant _USD_PRICE_MIN = 0.999e18;
    uint256 internal constant _USD_PRICE_MAX = 1.001e18;

    bytes32 internal _poolId;

    address internal _token0;
    address internal _token1;

    uint256 internal _unit0;
    uint256 internal _unit1;

    // Tick at which 1 USD of token0 is worth 1 USD of token1, at the time of the setup.
    int24 internal _fairTick;

    // Liquidity amount that corresponds to roughly 100k USD of each token over a 20 tick range.
    uint128 internal _liquidity;

    mapping(address token => bool isVault) internal _isVault;

    /**********************************************************************************************/
    /*** Setup helper functions                                                                 ***/
    /**********************************************************************************************/

    function _setUpTokens(address token0, bool isVault0, address token1, bool isVault1) internal {
        require(token0 < token1, "tokens-misordered");

        _token0 = token0;
        _token1 = token1;

        _unit0 = 10 ** IERC20Like(token0).decimals();
        _unit1 = 10 ** IERC20Like(token1).decimals();

        _isVault[token0] = isVault0;
        _isVault[token1] = isVault1;

        _fairTick  = _getFairTick();
        _liquidity = uint128(2e7 * Math.sqrt(_unit0 * _unit1));
    }

    function _setUpExistingPool(bytes32 poolId) internal {
        _poolId = poolId;

        _setUpKeysAndLimits();
    }

    // Creates a new pool at the fair price and seeds it with roughly 1m USD of each token.
    function _setUpNewPool() internal {
        PoolKey memory poolKey = PoolKey({
            currency0   : Currency.wrap(_token0),
            currency1   : Currency.wrap(_token1),
            fee         : 100,
            tickSpacing : 1,
            hooks       : IHooks(address(0))
        });

        _poolId = keccak256(abi.encode(poolKey));

        IPositionManagerPoolLike(_UNISWAP_V4_POSITION_MANAGER).initializePool(
            poolKey,
            _getFairSqrtPriceX96()
        );

        deal(_token0, _user, 10_000_000 * _unit0);
        deal(_token1, _user, 10_000_000 * _unit1);

        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR)
        );

        bytes[] memory params = new bytes[](2);

        params[0] = abi.encode(
            poolKey,
            _fairTick - 100,
            _fairTick + 100,
            uint256(_liquidity) * 10,
            type(uint128).max,
            type(uint128).max,
            _user,
            ""
        );

        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        vm.startPrank(_user);

        IERC20Like(_token0).approve(_PERMIT2, type(uint256).max);
        IERC20Like(_token1).approve(_PERMIT2, type(uint256).max);

        IPermit2Like(_PERMIT2).approve(_token0, _UNISWAP_V4_POSITION_MANAGER, type(uint160).max, type(uint48).max);
        IPermit2Like(_PERMIT2).approve(_token1, _UNISWAP_V4_POSITION_MANAGER, type(uint160).max, type(uint48).max);

        IPositionManagerPoolLike(_UNISWAP_V4_POSITION_MANAGER).modifyLiquidities(
            abi.encode(actions, params),
            block.timestamp
        );

        vm.stopPrank();

        _setUpKeysAndLimits();
    }

    function _setUpKeysAndLimits() internal {
        _aggregateDepositLimitKey  = mainnetController.uniswapV4_getAggregateDepositRateLimitKey(_poolId);
        _token0DepositLimitKey     = mainnetController.uniswapV4_getAssetDepositRateLimitKey(_poolId, _token0);
        _token1DepositLimitKey     = mainnetController.uniswapV4_getAssetDepositRateLimitKey(_poolId, _token1);
        _aggregateWithdrawLimitKey = mainnetController.uniswapV4_getAggregateWithdrawRateLimitKey(_poolId);
        _token0WithdrawLimitKey    = mainnetController.uniswapV4_getAssetWithdrawRateLimitKey(_poolId, _token0);
        _token1WithdrawLimitKey    = mainnetController.uniswapV4_getAssetWithdrawRateLimitKey(_poolId, _token1);
        _token0SwapLimitKey        = mainnetController.uniswapV4_getSwapRateLimitKey(_poolId, _token0);
        _token1SwapLimitKey        = mainnetController.uniswapV4_getSwapRateLimitKey(_poolId, _token1);

        vm.startPrank(SPARK_PROXY);

        rateLimits.setRateLimitData(_aggregateDepositLimitKey,  100_000_000e18,        0);
        rateLimits.setRateLimitData(_token0DepositLimitKey,     100_000_000 * _unit0,  0);
        rateLimits.setRateLimitData(_token1DepositLimitKey,     100_000_000 * _unit1,  0);
        rateLimits.setRateLimitData(_aggregateWithdrawLimitKey, 100_000_000e18,        0);
        rateLimits.setRateLimitData(_token0WithdrawLimitKey,    100_000_000 * _unit0,  0);
        rateLimits.setRateLimitData(_token1WithdrawLimitKey,    100_000_000 * _unit1,  0);
        rateLimits.setRateLimitData(_token0SwapLimitKey,        100_000_000 * _unit0,  0);
        rateLimits.setRateLimitData(_token1SwapLimitKey,        100_000_000 * _unit1,  0);

        // Wide raw tick limits, tight USD price limits.
        mainnetController.uniswapV4_setTickLimits({
            poolId               : _poolId,
            tickLowerMin         : _fairTick - 5_000,
            tickUpperMax         : _fairTick + 5_000,
            maxTickSpacing       : 100,
            tickLowerMinUsdPrice : _USD_PRICE_MIN,
            tickUpperMaxUsdPrice : _USD_PRICE_MAX
        });

        vm.stopPrank();

        deal(_token0, address(almProxy), 10_000_000 * _unit0);
        deal(_token1, address(almProxy), 10_000_000 * _unit1);
    }

    /**********************************************************************************************/
    /*** USD value helper functions                                                             ***/
    /**********************************************************************************************/

    // USD value of `amount` of `token` (1e18 precision).
    function _getUsdValue(address token, uint256 amount) internal view returns (uint256) {
        if (!_isVault[token]) return _toNormalizedAmount(token, amount);

        return _toNormalizedAmount(
            IERC4626Like(token).asset(),
            IERC4626Like(token).convertToAssets(amount)
        );
    }

    // USD value of token1 per 1 USD of token0, at `tick` (1e18 precision).
    function _getUsdPriceAtTick(int24 tick) internal view returns (uint256) {
        uint256 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);
        uint256 rawPriceX96  = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 96);

        return FullMath.mulDiv(
            rawPriceX96,
            _getUsdValue(_token1, _unit1) * _unit0 * 1e18,
            _getUsdValue(_token0, _unit0) * _unit1
        ) >> 96;
    }

    // Raw sqrt price at which 1 USD of token0 is worth 1 USD of token1.
    function _getFairSqrtPriceX96() internal view returns (uint160) {
        return uint160(
            Math.sqrt(
                FullMath.mulDiv(
                    _getUsdValue(_token0, _unit0) * _unit1,
                    1 << 192,
                    _getUsdValue(_token1, _unit1) * _unit0
                )
            )
        );
    }

    function _getFairTick() internal view returns (int24) {
        return TickMath.getTickAtSqrtPrice(_getFairSqrtPriceX96());
    }

    // Lowest tick with a USD price that is at least `usdPrice`.
    function _getLowestTickAbove(uint256 usdPrice) internal view returns (int24 tick) {
        tick = _getFairTick();

        while (_getUsdPriceAtTick(tick) >= usdPrice) --tick;
        while (_getUsdPriceAtTick(tick) <  usdPrice) ++tick;
    }

    // Highest tick with a USD price that is at most `usdPrice`.
    function _getHighestTickBelow(uint256 usdPrice) internal view returns (int24 tick) {
        tick = _getFairTick();

        while (_getUsdPriceAtTick(tick) <= usdPrice) ++tick;
        while (_getUsdPriceAtTick(tick) >  usdPrice) --tick;
    }

    // Lowest `amountOutMin` that satisfies the max slippage check for a swap of `amountIn`.
    function _getLowestAmountOutMin(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 maxSlippage
    )
        internal
        view
        returns (uint128)
    {
        uint256 usdValueIn = _getUsdValue(tokenIn, amountIn);

        // Binary search, as the USD value is monotonic in the amount.
        uint256 low  = 0;
        uint256 high = type(uint128).max;

        while (low < high) {
            uint256 mid = (low + high) / 2;

            if (_getUsdValue(tokenOut, mid) * 1e18 >= usdValueIn * maxSlippage) high = mid;
            else low = mid + 1;
        }

        return uint128(low);
    }

    /**********************************************************************************************/
    /*** Action helper functions                                                                ***/
    /**********************************************************************************************/

    function _mint(int24 tickLower, int24 tickUpper) internal returns (uint256 tokenId) {
        vm.prank(allocator);
        mainnetController.uniswapV4_mintPosition({
            poolId     : _poolId,
            tickLower  : tickLower,
            tickUpper  : tickUpper,
            liquidity  : _liquidity,
            amount0Max : uint128(10_000_000 * _unit0),
            amount1Max : uint128(10_000_000 * _unit1)
        });

        return IPositionManagerLike(_UNISWAP_V4_POSITION_MANAGER).nextTokenId() - 1;
    }

    function _increase(uint256 tokenId) internal {
        vm.prank(allocator);
        mainnetController.uniswapV4_increasePosition({
            poolId            : _poolId,
            tokenId           : tokenId,
            liquidityIncrease : _liquidity,
            amount0Max        : uint128(10_000_000 * _unit0),
            amount1Max        : uint128(10_000_000 * _unit1)
        });
    }

    function _setUsdPriceLimits(uint256 tickLowerMinUsdPrice, uint256 tickUpperMaxUsdPrice)
        internal
    {
        vm.prank(SPARK_PROXY);
        mainnetController.uniswapV4_setTickLimits({
            poolId               : _poolId,
            tickLowerMin         : _fairTick - 5_000,
            tickUpperMax         : _fairTick + 5_000,
            maxTickSpacing       : 100,
            tickLowerMinUsdPrice : tickLowerMinUsdPrice,
            tickUpperMaxUsdPrice : tickUpperMaxUsdPrice
        });
    }

    /**********************************************************************************************/
    /*** USD price tick limit tests (all pools)                                                 ***/
    /**********************************************************************************************/

    function test_uniswapV4_usdPrice_fairTick() external view {
        // The USD price is 1 at the fair tick (within one tick, i.e. 1bp), regardless of the
        // decimals and the exchange rates of the tokens.
        assertApproxEqRel(_getUsdPriceAtTick(_fairTick), 1e18, 0.0001e18);
    }

    function test_uniswapV4_mintPosition_usdPriceBoundaries() external {
        int24 tickLower = _getLowestTickAbove(_USD_PRICE_MIN);
        int24 tickUpper = _getHighestTickBelow(_USD_PRICE_MAX);

        // 0.999 to 1.001 is roughly 10 ticks on each side of the fair tick.
        assertApproxEqAbs(tickLower, _fairTick - 10, 1);
        assertApproxEqAbs(tickUpper, _fairTick + 10, 1);

        vm.expectRevert("UniswapV4Facet/tickLower-usd-price-too-low");
        this.externalMint(tickLower - 1, tickUpper);

        vm.expectRevert("UniswapV4Facet/tickUpper-usd-price-too-high");
        this.externalMint(tickLower, tickUpper + 1);

        uint256 tokenId = _mint(tickLower, tickUpper);

        assertEq(
            IPositionManagerLike(_UNISWAP_V4_POSITION_MANAGER).ownerOf(tokenId),
            address(almProxy)
        );

        assertEq(
            IPositionManagerLike(_UNISWAP_V4_POSITION_MANAGER).getPositionLiquidity(tokenId),
            _liquidity
        );
    }

    function test_uniswapV4_increasePosition_usdPriceBoundaries() external {
        int24 tickLower = _getLowestTickAbove(_USD_PRICE_MIN);
        int24 tickUpper = _getHighestTickBelow(_USD_PRICE_MAX);

        uint256 tokenId = _mint(tickLower, tickUpper);

        // Position USD prices are re-checked against the current limits on increase.
        _setUsdPriceLimits(_getUsdPriceAtTick(tickLower) + 1, _USD_PRICE_MAX);

        vm.expectRevert("UniswapV4Facet/tickLower-usd-price-too-low");
        this.externalIncrease(tokenId);

        _setUsdPriceLimits(_USD_PRICE_MIN, _getUsdPriceAtTick(tickUpper) - 1);

        vm.expectRevert("UniswapV4Facet/tickUpper-usd-price-too-high");
        this.externalIncrease(tokenId);

        _setUsdPriceLimits(_getUsdPriceAtTick(tickLower), _getUsdPriceAtTick(tickUpper));

        _increase(tokenId);

        assertEq(
            IPositionManagerLike(_UNISWAP_V4_POSITION_MANAGER).getPositionLiquidity(tokenId),
            _liquidity * 2
        );
    }

    // NOTE: External wrappers so that `vm.expectRevert` applies to the controller call and not to
    //       the view calls made by the helpers.
    function externalMint(int24 tickLower, int24 tickUpper) external {
        _mint(tickLower, tickUpper);
    }

    function externalIncrease(uint256 tokenId) external {
        _increase(tokenId);
    }

}

/**
 * @dev Tests that only apply to pools where at least one token is an ERC4626 vault.
 */
abstract contract UniswapV4_YieldBearing_Tests is UniswapV4_UsdPrice_TestBase {

    /**********************************************************************************************/
    /*** Aggregate rate limit tests                                                             ***/
    /**********************************************************************************************/

    function test_uniswapV4_yieldBearing_aggregateRateLimitsInUsdValue() external {
        uint256 balance0 = IERC20Like(_token0).balanceOf(address(almProxy));
        uint256 balance1 = IERC20Like(_token1).balanceOf(address(almProxy));

        uint256 tokenId = _mint(
            _getLowestTickAbove(_USD_PRICE_MIN),
            _getHighestTickBelow(_USD_PRICE_MAX)
        );

        uint256 amount0 = balance0 - IERC20Like(_token0).balanceOf(address(almProxy));
        uint256 amount1 = balance1 - IERC20Like(_token1).balanceOf(address(almProxy));

        assertGt(amount0, 0);
        assertGt(amount1, 0);

        uint256 usdValue = _getUsdValue(_token0, amount0) + _getUsdValue(_token1, amount1);

        // Vault shares are valued at more than 1 USD each.
        assertGt(
            usdValue,
            _toNormalizedAmount(_token0, amount0) + _toNormalizedAmount(_token1, amount1)
        );

        // Aggregate rate limit is charged in USD value (up to the rounding of `convertToAssets`),
        // per-asset rate limits are charged in token amounts.
        assertApproxEqAbs(
            100_000_000e18 - rateLimits.getCurrentRateLimit(_aggregateDepositLimitKey),
            usdValue,
            2e12
        );

        assertEq(100_000_000 * _unit0 - rateLimits.getCurrentRateLimit(_token0DepositLimitKey), amount0);
        assertEq(100_000_000 * _unit1 - rateLimits.getCurrentRateLimit(_token1DepositLimitKey), amount1);

        balance0 = IERC20Like(_token0).balanceOf(address(almProxy));
        balance1 = IERC20Like(_token1).balanceOf(address(almProxy));

        vm.prank(allocator);
        mainnetController.uniswapV4_decreasePosition(_poolId, tokenId, _liquidity, 0, 0);

        amount0 = IERC20Like(_token0).balanceOf(address(almProxy)) - balance0;
        amount1 = IERC20Like(_token1).balanceOf(address(almProxy)) - balance1;

        assertGt(amount0, 0);
        assertGt(amount1, 0);

        assertApproxEqAbs(
            100_000_000e18 - rateLimits.getCurrentRateLimit(_aggregateWithdrawLimitKey),
            _getUsdValue(_token0, amount0) + _getUsdValue(_token1, amount1),
            2e12
        );

        assertEq(100_000_000 * _unit0 - rateLimits.getCurrentRateLimit(_token0WithdrawLimitKey), amount0);
        assertEq(100_000_000 * _unit1 - rateLimits.getCurrentRateLimit(_token1WithdrawLimitKey), amount1);
    }

    /**********************************************************************************************/
    /*** Swap max slippage tests                                                                ***/
    /**********************************************************************************************/

    function test_uniswapV4_yieldBearing_swap_token0ToToken1_maxSlippageInUsdValue() external {
        _test_swap_maxSlippageInUsdValue(_token0, _token1, 10_000 * _unit0);
    }

    function test_uniswapV4_yieldBearing_swap_token1ToToken0_maxSlippageInUsdValue() external {
        _test_swap_maxSlippageInUsdValue(_token1, _token0, 10_000 * _unit1);
    }

    function _test_swap_maxSlippageInUsdValue(address tokenIn, address tokenOut, uint256 amountIn)
        internal
    {
        vm.prank(SPARK_PROXY);
        mainnetController.uniswapV4_setMaxSlippage(_poolId, 0.999e18);

        uint128 amountOutMin = _getLowestAmountOutMin(tokenIn, tokenOut, amountIn, 0.999e18);

        // The lowest valid `amountOutMin` is worth 99.9% of `amountIn` in USD terms...
        assertApproxEqRel(
            _getUsdValue(tokenOut, amountOutMin),
            _getUsdValue(tokenIn, amountIn) * 0.999e18 / 1e18,
            1e12
        );

        // ...which differs from 99.9% of `amountIn` in token terms.
        assertNotEq(
            _toNormalizedAmount(tokenOut, amountOutMin),
            _toNormalizedAmount(tokenIn, amountIn) * 0.999e18 / 1e18
        );

        vm.expectRevert("UniswapV4Facet/amountOutMin-too-low");
        vm.prank(allocator);
        mainnetController.uniswapV4_swap(_poolId, tokenIn, uint128(amountIn), amountOutMin - 1);

        uint256 amountOut = _swap(_poolId, tokenIn, uint128(amountIn), amountOutMin);

        assertGe(amountOut, amountOutMin);
    }

}

/**************************************************************************************************/
/*** USD-pegged / USD-pegged (existing pool, 6 and 18 decimals)                                 ***/
/**************************************************************************************************/

contract MainnetController_UniswapV4_UsdPrice_USDT_USDS_Tests is UniswapV4_UsdPrice_TestBase {

    function setUp() public override {
        super.setUp();

        _setUpTokens(Ethereum.USDT, false, Ethereum.USDS, false);

        _setUpExistingPool(0xb54ece65cc2ddd3eaec0ad18657470fb043097220273d87368a062c7d4e59180);
    }

    function test_uniswapV4_usdPrice_decimals() external view {
        // Raw price of 1e12 USDS base units per USDT base unit is a USD price of 1.
        assertEq(_fairTick, 276_324);
    }

}

/**************************************************************************************************/
/*** ERC4626 / USD-pegged                                                                       ***/
/**************************************************************************************************/

contract MainnetController_UniswapV4_UsdPrice_SUSDS_USDT_Tests is UniswapV4_YieldBearing_Tests {

    function setUp() public override {
        super.setUp();

        _setUpTokens(Ethereum.SUSDS, true, Ethereum.USDT, false);

        _setUpNewPool();
    }

    function test_uniswapV4_mintPosition_usdPriceLimitsTrackVaultRate() external {
        int24 tickLower = _getLowestTickAbove(_USD_PRICE_MIN);
        int24 tickUpper = _getHighestTickBelow(_USD_PRICE_MAX);

        uint256 tokenId = _mint(tickLower, tickUpper);

        uint256 rate = IERC4626Like(Ethereum.SUSDS).convertToAssets(1e18);

        skip(365 days);

        // sUSDS has accrued yield, so the same raw ticks are now a lower USDT per USDS price.
        assertGt(IERC4626Like(Ethereum.SUSDS).convertToAssets(1e18), rate * 1.04e18 / 1e18);

        vm.expectRevert("UniswapV4Facet/tickLower-usd-price-too-low");
        this.externalMint(tickLower, tickUpper);

        vm.expectRevert("UniswapV4Facet/tickLower-usd-price-too-low");
        this.externalIncrease(tokenId);

        // Without any governance action, the allowed raw tick range has moved with the rate.
        int24 newTickLower = _getLowestTickAbove(_USD_PRICE_MIN);
        int24 newTickUpper = _getHighestTickBelow(_USD_PRICE_MAX);

        assertGt(newTickLower, tickLower + 390);
        assertGt(newTickUpper, tickUpper + 390);

        assertEq(newTickUpper - newTickLower, tickUpper - tickLower);

        vm.expectRevert("UniswapV4Facet/tickLower-usd-price-too-low");
        this.externalMint(newTickLower - 1, newTickUpper);

        vm.expectRevert("UniswapV4Facet/tickUpper-usd-price-too-high");
        this.externalMint(newTickLower, newTickUpper + 1);

        _mint(newTickLower, newTickUpper);
    }

    function test_uniswapV4_mintPosition_rawTickLimitsBoundManipulatedVaultRate() external {
        // The vault rate is manipulated to double, which moves the range of ticks that satisfy the
        // USD price limits by ~6931 ticks.
        vm.mockCall(
            Ethereum.SUSDS,
            abi.encodeCall(IERC4626Like.convertToAssets, (1e18)),
            abi.encode(IERC4626Like(Ethereum.SUSDS).convertToAssets(1e18) * 2)
        );

        int24 tickLower = _getLowestTickAbove(_USD_PRICE_MIN);
        int24 tickUpper = _getHighestTickBelow(_USD_PRICE_MAX);

        assertApproxEqAbs(tickLower, _fairTick + 6_931 - 10, 2);
        assertApproxEqAbs(tickUpper, _fairTick + 6_931 + 10, 2);

        // The raw tick limits do not depend on the vault rate, so the position is rejected.
        vm.expectRevert("UniswapV4Facet/tickUpper-too-high");
        this.externalMint(tickLower, tickUpper);

        // The position would have been accepted with the USD price limits alone.
        vm.prank(SPARK_PROXY);
        mainnetController.uniswapV4_setTickLimits({
            poolId               : _poolId,
            tickLowerMin         : _fairTick - 10_000,
            tickUpperMax         : _fairTick + 10_000,
            maxTickSpacing       : 100,
            tickLowerMinUsdPrice : _USD_PRICE_MIN,
            tickUpperMaxUsdPrice : _USD_PRICE_MAX
        });

        _mint(tickLower, tickUpper);
    }

}

/**************************************************************************************************/
/*** ERC4626 / ERC4626 (underlying assets with 18 and 6 decimals)                               ***/
/**************************************************************************************************/

contract MainnetController_UniswapV4_UsdPrice_SUSDS_SUSDC_Tests is UniswapV4_YieldBearing_Tests {

    function setUp() public override {
        super.setUp();

        _setUpTokens(Ethereum.SUSDS, true, Ethereum.SUSDC, true);

        _setUpNewPool();
    }

}
