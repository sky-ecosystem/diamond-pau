// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ReentrancyGuard } from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

import { FullMath } from "../../lib/dss-allocator/src/funnels/uniV3/FullMath.sol";
import { TickMath } from "../../lib/dss-allocator/src/funnels/uniV3/TickMath.sol";

import { ERC20Mock } from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base } from "../../lib/spark-address-registry/src/Base.sol";

import { IUniswapV3Facet } from "../../src/facets/uniswap-v3/IUniswapV3Facet.sol";

import { makeAddressAddressKey } from "../../src/libraries/RateLimitHelpers.sol";

import {
    INonfungiblePositionManagerLike,
    ISwapRouterLike,
    IUniswapV3PoolLike
} from "../interfaces/UniswapV3.sol";

import { ForkTestBase } from "./ForkTestBase.t.sol";

interface IAccessControlLike {

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

}

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

}

interface IERC721Like {

    function transferFrom(address from, address to, uint256 tokenId) external;

}

interface IUniswapV3FactoryLike {

    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);

}

abstract contract UniswapV3_TestBase is ForkTestBase {

    address constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    int24 internal constant DEFAULT_TICK_LOWER = -600;
    int24 internal constant DEFAULT_TICK_UPPER =  600;

    address internal usdsAusdPool;
    address internal usdsUsdcPool;

    IERC20Like internal ausdBase;

    bytes32 internal uniswapV3_UsdsUsdcPool_UsdsSwapKey;
    bytes32 internal uniswapV3_UsdsUsdcPool_UsdcSwapKey;
    bytes32 internal uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey;
    bytes32 internal uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey;
    bytes32 internal uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey;
    bytes32 internal uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey;

    bytes32 internal uniswapV3_AusdUsdsPool_AusdSwapKey;
    bytes32 internal uniswapV3_AusdUsdsPool_UsdsSwapKey;
    bytes32 internal uniswapV3_AusdUsdsPool_AusdAddLiquidityKey;
    bytes32 internal uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey;
    bytes32 internal uniswapV3_AusdUsdsPool_AusdRemoveLiquidityKey;
    bytes32 internal uniswapV3_AusdUsdsPool_UsdsRemoveLiquidityKey;

    IERC20Like internal token0;
    IERC20Like internal token1;

    address internal pool;
    uint24  internal poolFee;
    uint8   internal token0Decimals;
    int24   internal initTick;

    address internal stranger     = makeAddr("stranger");
    address internal unauthorized = makeAddr("unauthorized");

    function setUp() public virtual override  {
        super.setUp();

        ausdBase = IERC20Like(address(new ERC20Mock()));

        usdsAusdPool = _createPool(address(ausdBase), address(usdsBase), 100);
        usdsUsdcPool = _createPool(address(usdsBase), address(usdcBase), 100);

        vm.warp(block.timestamp + 2 hours); // Advance sufficient time for twap

        uniswapV3_UsdsUsdcPool_UsdsSwapKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_SWAP(),
            address(usdsBase),
            usdsUsdcPool
        );

        uniswapV3_UsdsUsdcPool_UsdcSwapKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_SWAP(),
            address(usdcBase),
            usdsUsdcPool
        );

        uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_DEPOSIT(),
            address(usdsBase),
            usdsUsdcPool
        );

        uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_DEPOSIT(),
            address(usdcBase),
            usdsUsdcPool
        );

        uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_WITHDRAW(),
            address(usdsBase),
            usdsUsdcPool
        );

        uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_WITHDRAW(),
            address(usdcBase),
            usdsUsdcPool
        );

        uniswapV3_AusdUsdsPool_AusdSwapKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_SWAP(),
            address(ausdBase),
            usdsAusdPool
        );

        uniswapV3_AusdUsdsPool_UsdsSwapKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_SWAP(),
            address(usdsBase),
            usdsAusdPool
        );

        uniswapV3_AusdUsdsPool_AusdAddLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_DEPOSIT(),
            address(ausdBase),
            usdsAusdPool
        );

        uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_DEPOSIT(),
            address(usdsBase),
            usdsAusdPool
        );

        uniswapV3_AusdUsdsPool_AusdRemoveLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_WITHDRAW(),
            address(ausdBase),
            usdsAusdPool
        );

        uniswapV3_AusdUsdsPool_UsdsRemoveLiquidityKey = makeAddressAddressKey(
            foreignController.LIMIT_UNISWAP_V3_WITHDRAW(),
            address(usdsBase),
            usdsAusdPool
        );

        vm.startPrank(Base.SPARK_EXECUTOR);

        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdsSwapKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdcSwapKey, 1_000_000e6,  uint256(1_000_000e6)  / 1 days);

        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey, 1_000_000e6,  uint256(1_000_000e6)  / 1 days);
        rateLimits.setRateLimitData(uniswapV3_AusdUsdsPool_AusdAddLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);

        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_AusdUsdsPool_AusdRemoveLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);
        rateLimits.setRateLimitData(uniswapV3_AusdUsdsPool_UsdsRemoveLiquidityKey, 1_000_000e18, uint256(1_000_000e18) / 1 days);

        foreignController.setUniswapV3MaxSlippage(_getPool(), 0.98e18);
        foreignController.setUniswapV3PoolMaxTickDelta(_getPool(), 200);

        // Pools are new so need a shorter twap for testing
        foreignController.setUniswapV3TWAPSecondsAgo(_getPool(), 1 hours);

        vm.stopPrank();

        token0         = IERC20Like(IUniswapV3PoolLike(_getPool()).token0());
        token1         = IERC20Like(IUniswapV3PoolLike(_getPool()).token1());
        poolFee        = IUniswapV3PoolLike(_getPool()).fee();
        token0Decimals = IERC20Like(address(token0)).decimals();
        initTick       = TickMath.getTickAtSqrtRatio(_getInitialSqrtPriceX96(address(token0), address(token1)));

        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_getPool(), initTick - 1000);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_getPool(), initTick + 1000);
        vm.stopPrank();

        _label();
    }

    function _getInitialSqrtPriceX96(address _token0, address _token1) internal view returns (uint160) {
        uint8 decimals0 = IERC20Like(_token0).decimals();
        uint8 decimals1 = IERC20Like(_token1).decimals();

        // rawPrice = 10^(dec1 - dec0)
        int256 exp = int256(uint256(decimals1)) - int256(uint256(decimals0));

        if (exp >= 0) {
            return uint160((uint256(1) << 96) * 10 ** uint256(exp / 2));
        } else {
            return uint160((uint256(1) << 96) / 10 ** uint256(-exp / 2));
        }
    }

    // @dev According to Uniswap V3 docs, token0/token1 ordering is not enforced when creating a pool.
    function _createPool(
        address _tokenA,
        address _tokenB,
        uint24 _fee
    ) internal returns (address poolAddress) {
        IUniswapV3FactoryLike factory = IUniswapV3FactoryLike(UNISWAP_V3_FACTORY);

        poolAddress = factory.createPool(_tokenA, _tokenB, _fee);

        uint160 sqrtPriceX96 = _getInitialSqrtPriceX96(_tokenA, _tokenB);
        IUniswapV3PoolLike(poolAddress).initialize(sqrtPriceX96);
    }


    function _getSwapKey(address tokenIn) internal view returns (bytes32) {
        return makeAddressAddressKey(foreignController.LIMIT_UNISWAP_V3_SWAP(), tokenIn, _getPool());
    }

    function _label() internal {
        vm.label(UNISWAP_V3_ROUTER,           'UniswapV3Router');
        vm.label(UNISWAP_V3_POSITION_MANAGER, 'UniswapV3PositionManager');
        vm.label(address(ausdBase),           'AUSD');
        vm.label(address(usdcBase),           'USDC');
        vm.label(address(usdsBase),           'USDS');
        vm.label(usdsUsdcPool,                'USDS-USDC Pool');
        vm.label(usdsAusdPool,                'AUSD-USDS Pool');
    }

    function _getPool() internal view virtual returns (address) {
        return usdsUsdcPool;
    }

    function _getBlock() internal pure override returns (uint256) {
        return 37973959;  // Nov 9, 2025
    }

    function _fundProxy(uint256 amount0Desired, uint256 amount1Desired) internal {
        deal(address(token0), almProxy, amount0Desired);
        deal(address(token1), almProxy, amount1Desired);
    }

    function _addLiquidity(
        uint256                             tokenId_,
        IUniswapV3Facet.Ticks        memory tick_,
        IUniswapV3Facet.TokenAmounts memory desired_,
        IUniswapV3Facet.TokenAmounts memory min_
    )
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0Used, uint256 amount1Used)
    {
        IUniswapV3Facet.TokenAmounts memory amountsUsed;

        vm.prank(RELAYER);
        ( tokenId, liquidity, amountsUsed ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId_,
            tick_,
            desired_,
            min_,
            block.timestamp + 1 hours
        );

        amount0Used = amountsUsed.amount0;
        amount1Used = amountsUsed.amount1;
    }

    function _minLiquidityPosition(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (IUniswapV3Facet.TokenAmounts memory)
    {
        return IUniswapV3Facet.TokenAmounts({
            amount0 : amount0 * 98 / 100,
            amount1 : amount1 * 98 / 100
        });
    }

}

contract ForeignController_UniswapV3_Swap_Tests is UniswapV3_TestBase {

    function _getPool() internal view override returns (address) {
        return usdsUsdcPool;
    }

    function test_swapUniswapV3_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.swapUniswapV3(
            _getPool(),
            address(token0),
            1,
            1,
            100
        );
    }

    function test_swapUniswapV3_notRelayer() external {
        vm.expectRevert(abi.encodeWithSelector(
            IAccessControlLike.AccessControlUnauthorizedAccount.selector,
            unauthorized,
            RELAYER_ROLE
        ));
        vm.prank(unauthorized);
        foreignController.swapUniswapV3(
            _getPool(),
            address(token0),
            1,
            1,
            100
        );
    }

    function test_swapUniswapV3_invalidTokenPair() external {
        vm.expectRevert("UniswapV3Facet/invalid-token-pair");
        vm.prank(RELAYER);
        foreignController.swapUniswapV3(
            _getPool(),
            address(ausdBase),
            1,
            1,
            100
        );
    }

}

contract ForeignController_UniswapV3_AddLiquidity_FailureTests is UniswapV3_TestBase {

    function _defaultTickRange() internal view returns (IUniswapV3Facet.Ticks memory) {
        return IUniswapV3Facet.Ticks({ lower: initTick - 100, upper: initTick + 100 });
    }

    function _defaultDesiredPosition() internal view returns (IUniswapV3Facet.TokenAmounts memory) {
        uint256 amount0 = 1000 * 10 ** uint256(token0Decimals);
        uint256 amount1 = 1000 * 10 ** uint256(IERC20Like(address(token1)).decimals());

        return IUniswapV3Facet.TokenAmounts({ amount0: amount0, amount1: amount1 });
    }

    function _defaultMinPosition(IUniswapV3Facet.TokenAmounts memory desired)
        internal
        pure
        returns (IUniswapV3Facet.TokenAmounts memory)
    {
        return IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 99 / 100,
            amount1: desired.amount1 * 99 / 100
        });
    }

    function _prepareDefaultAddLiquidity()
        internal
        returns (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        )
    {
        tick = _defaultTickRange();
        desired = _defaultDesiredPosition();
        min = _defaultMinPosition(desired);
        _fundProxy(desired.amount0, desired.amount1);
    }

    function _mintExternalPosition() internal returns (uint256 tokenId) {
        uint256 amount0 = 5 * 10 ** uint256(token0Decimals);
        uint8 token1Decimals = IERC20Like(address(token1)).decimals();
        uint256 amount1 = 5 * 10 ** uint256(token1Decimals);

        deal(address(token0), stranger, amount0);
        deal(address(token1), stranger, amount1);

        vm.startPrank(stranger);

        token0.approve(UNISWAP_V3_POSITION_MANAGER, amount0);
        token1.approve(UNISWAP_V3_POSITION_MANAGER, amount1);

        ( tokenId, , , ) = INonfungiblePositionManagerLike(UNISWAP_V3_POSITION_MANAGER).mint(
            INonfungiblePositionManagerLike.MintParams({
                token0         : address(token0),
                token1         : address(token1),
                fee            : poolFee,
                tickLower      : initTick - 50,
                tickUpper      : initTick + 50,
                amount0Desired : amount0,
                amount1Desired : amount1,
                amount0Min     : 0,
                amount1Min     : 0,
                recipient      : stranger,
                deadline       : block.timestamp + 1 hours
            })
        );

        vm.stopPrank();
    }

    function test_addLiquidityUniswapV3_reentrancy() external {
        _setControllerEntered();

        (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        ) = _prepareDefaultAddLiquidity();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_notRelayer() external {
        (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        ) = _prepareDefaultAddLiquidity();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlLike.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                RELAYER_ROLE
            )
        );
        vm.prank(unauthorized);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_zeroAmount() external {
        IUniswapV3Facet.Ticks memory tick = _defaultTickRange();
        IUniswapV3Facet.TokenAmounts memory zeroPosition = IUniswapV3Facet.TokenAmounts({
            amount0: 0,
            amount1: 0
        });

        vm.expectRevert("UniswapV3Facet/zero-amount");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            zeroPosition,
            zeroPosition,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_maxSlippageNotSet() external {
        (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        ) = _prepareDefaultAddLiquidity();

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3MaxSlippage(_getPool(), 0);

        vm.expectRevert("UniswapV3Facet/max-slippage-not-set");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_invalidTickLower() external {
        (IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, IUniswapV3Facet.TokenAmounts memory min)
            = _prepareDefaultAddLiquidity();
        tick.lower = initTick - 2000;

        vm.expectRevert("UniswapV3Facet/lower-tick-outside-bounds");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_invalidTickUpper() external {
        (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        ) = _prepareDefaultAddLiquidity();

        tick.upper = initTick + 2000;

        vm.expectRevert("UniswapV3Facet/upper-tick-outside-bounds");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_minAmount0BelowBound() external {
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        IUniswapV3Facet.TokenAmounts memory min = IUniswapV3Facet.TokenAmounts({
            amount0: 0,
            amount1: desired.amount1 * 98/100
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_minAmount1BelowBound() external {
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        IUniswapV3Facet.TokenAmounts memory min = IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 98 / 100,
            amount1: 0
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_proxyDoesNotOwnTokenId() external {
        uint256 tokenId = _mintExternalPosition();

        vm.warp(block.timestamp + 1 hours);

        (
            IUniswapV3Facet.Ticks        memory tick,
            IUniswapV3Facet.TokenAmounts memory desired,
            IUniswapV3Facet.TokenAmounts memory min
        ) = _prepareDefaultAddLiquidity();

        vm.expectRevert("UniswapV3Facet/proxy-does-not-own-token-id");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId,
            tick,
            desired,
            min,
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_rateLimitExceeded_token0() external {
        uint256 amount0 = 2_000_000e18;
        uint256 amount1 = 0;

        _fundProxy(amount0, amount1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            IUniswapV3Facet.Ticks({
                lower: initTick + 50,
                upper: initTick + 100
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: amount0,
                amount1: amount1
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: amount0 * 98 / 100,
                amount1: amount1 * 98 / 100
            }),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_rateLimitExceeded_token1() external {
        uint256 amount0 = 0;
        uint256 amount1 = 2_000_000e6;

        _fundProxy(amount0, amount1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            IUniswapV3Facet.Ticks({
                lower: initTick - 100,
                upper: initTick - 50
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: amount0,
                amount1: amount1
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: amount0 * 98 / 100,
                amount1: amount1 * 98 / 100
            }),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_invalidPoolForPosition() external {
        // Set arbitrary values
        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3MaxSlippage(usdsAusdPool, 0.000001 * 1e18);
        foreignController.setUniswapV3TWAPSecondsAgo(usdsAusdPool, 1 seconds);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(usdsAusdPool, -100000);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(usdsAusdPool, 100000);
        vm.stopPrank();

        // Mint a USDS-USDC position and transfer it to the relayer
        uint256 usdsUsdcTokenId = _mintExternalPosition();

        vm.prank(stranger);
        IERC721Like(UNISWAP_V3_POSITION_MANAGER).transferFrom(stranger, almProxy, usdsUsdcTokenId);

        vm.warp(block.timestamp + 1 hours);

        vm.expectRevert("UniswapV3Facet/invalid-pool");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            usdsAusdPool,
            usdsUsdcTokenId, // USDS-USDC pool token ID
            IUniswapV3Facet.Ticks({
                lower: -10000,
                upper: 10000
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: 1,
                amount1: 1
            }),
            IUniswapV3Facet.TokenAmounts({
                amount0: 0,
                amount1: 0
            }),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_lowerTickDoesNotMatchPosition() external {
        // Create new default position
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        vm.prank(RELAYER);
        ( uint256 tokenId, , ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 2 hours);

        // Adding liquidity with the different lower tick bound should fail
        vm.expectRevert("UniswapV3Facet/lower-tick-does-not-match-position");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId,
            IUniswapV3Facet.Ticks({
                lower: tick.lower + 1,
                upper: tick.upper
            }),
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_upperTickDoesNotMatchPosition() external {
        // Create new default position
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        vm.prank(RELAYER);
        ( uint256 tokenId, , ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 2 hours);

        // Adding liquidity with the different upper tick bound should fail
        vm.expectRevert("UniswapV3Facet/upper-tick-does-not-match-position");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId,
            IUniswapV3Facet.Ticks({
                lower: tick.lower,
                upper: tick.upper + 1
            }),
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_failsAfterLowerTickBoundChanges() external {
        // Create new default position
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        vm.prank(RELAYER);
        ( uint256 tokenId, , ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 2 hours);

        // Change tick bounds
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_getPool(), tick.lower + 100);

        // Adding liquidity with the same tick bounds before the change should fail
        vm.expectRevert("UniswapV3Facet/lower-tick-outside-bounds");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );
    }

    function test_addLiquidityUniswapV3_failsAfterUpperTickBoundChanges() external {
        // Create new default position
        ( IUniswapV3Facet.Ticks memory tick, IUniswapV3Facet.TokenAmounts memory desired, ) = _prepareDefaultAddLiquidity();

        vm.prank(RELAYER);
        ( uint256 tokenId, , ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );

        vm.warp(block.timestamp + 2 hours);

        // Change tick bounds
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_getPool(), tick.upper - 100);

        // Adding liquidity with the same tick bounds before the change should fail
        vm.expectRevert("UniswapV3Facet/upper-tick-outside-bounds");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            tokenId,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );
    }

}

contract ForeignController_UniswapV3_AddLiquidity_TWAPProtectionTests is UniswapV3_TestBase {

    function _defaultDesiredPosition() internal view returns (IUniswapV3Facet.TokenAmounts memory) {
        uint256 amount0 = 10_000 * 10 ** uint256(token0Decimals);
        uint256 amount1 = 10_000 * 10 ** uint256(IERC20Like(address(token1)).decimals());

        return IUniswapV3Facet.TokenAmounts({ amount0: amount0, amount1: amount1 });
    }

    function _mockSpotTick(int24 spotTick) internal {
        // Mock slot0 to return a manipulated spot tick
        // slot0 returns: (sqrtPriceX96, tick, observationIndex, observationCardinality, observationCardinalityNext, feeProtocol, unlocked)
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(spotTick);
        vm.mockCall(
            _getPool(),
            abi.encodeWithSignature("slot0()"),
            abi.encode(sqrtPriceX96, spotTick, uint16(0), uint16(1), uint16(1), uint8(0), true)
        );
    }

    // Transaction fails when spot price has been manipulated out of expected range
    // Even with valid TWAP-based min amounts, Uniswap's own slippage check fails
    // because spot price requires different token ratios than our mins allow
    function test_addLiquidityUniswapV3_twapProtection_revertsWhenSpotPriceManipulated() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        // Position range around current TWAP (which is close to spot in normal conditions)
        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick - 100,
            upper: initTick + 100
        });

        // Mock spot price to be way above our tick range (manipulated)
        // At this spot price, Uniswap will want mostly token1, not the balanced amounts we're providing
        _mockSpotTick(tick.upper + 1000);

        // Min amounts are valid per TWAP, but spot price is manipulated
        // Uniswap's mint will fail because actual amounts needed don't match our mins
        IUniswapV3Facet.TokenAmounts memory minAmounts = IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 98 / 100,
            amount1: desired.amount1 * 98 / 100
        });

        vm.expectRevert("Price slippage check");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            minAmounts,
            block.timestamp + 1 hours
        );

        vm.clearMockedCalls();
    }

    // When TWAP tick is above tick.upper, expectedAmount0 = 0
    // So minAmount0 must be 0, otherwise revert
    function test_addLiquidityUniswapV3_twapProtection_revertsWhenTWAPAboveRangeAndMinAmount0NonZero() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        // Set governance bounds entirely below the current TWAP
        // Pool's TWAP is near initTick, so setting bounds below that puts TWAP above our allowed range
        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_getPool(), initTick - 300);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_getPool(), initTick - 100);
        vm.stopPrank();

        // Relayer uses ticks within governance bounds
        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick - 200,
            upper: initTick - 100
        });

        // Incorrectly provide non-zero minAmount0 when TWAP expects only token1
        IUniswapV3Facet.TokenAmounts memory minAmounts = IUniswapV3Facet.TokenAmounts({
            amount0: 1, // Should be 0 when twapTick >= tick.upper
            amount1: desired.amount1 * 98 / 100
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            minAmounts,
            block.timestamp + 1 hours
        );
    }

    // When TWAP tick is below tick.lower, expectedAmount1 = 0
    // So minAmount1 must be 0, otherwise revert
    function test_addLiquidityUniswapV3_twapProtection_revertsWhenTWAPBelowRangeAndMinAmount1NonZero() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        // Set governance bounds entirely above the current TWAP
        // Pool's TWAP is near initTick, so setting bounds above that puts TWAP below our allowed range
        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3AddLiquidityLowerTickBound(_getPool(), initTick + 100);
        foreignController.setUniswapV3AddLiquidityUpperTickBound(_getPool(), initTick + 300);
        vm.stopPrank();

        // Relayer uses ticks within governance bounds
        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick + 100,
            upper: initTick + 200
        });

        // Incorrectly provide non-zero minAmount1 when TWAP expects only token0
        IUniswapV3Facet.TokenAmounts memory minAmounts = IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 98 / 100,
            amount1: 1 // Should be 0 when twapTick <= tick.lower
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            minAmounts,
            block.timestamp + 1 hours
        );
    }

    // When TWAP is within tick range, minAmount0 must meet threshold
    function test_addLiquidityUniswapV3_twapProtection_revertsWhenMinAmount0TooLow() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        // Position range around current TWAP, so both tokens are expected
        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick - 100,
            upper: initTick + 100
        });

        // minAmount0 is too low (50%) while maxSlippage requires 98%
        IUniswapV3Facet.TokenAmounts memory minAmounts = IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 50 / 100, // Too low
            amount1: desired.amount1 * 98 / 100  // Acceptable
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            minAmounts,
            block.timestamp + 1 hours
        );
    }

    // When TWAP is within tick range, minAmount1 must meet threshold
    function test_addLiquidityUniswapV3_twapProtection_revertsWhenMinAmount1TooLow() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        // Position range around current TWAP, so both tokens are expected
        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick - 100,
            upper: initTick + 100
        });

        // minAmount1 is too low (50%) while maxSlippage requires 98%
        IUniswapV3Facet.TokenAmounts memory minAmounts = IUniswapV3Facet.TokenAmounts({
            amount0: desired.amount0 * 98 / 100, // Acceptable
            amount1: desired.amount1 * 50 / 100  // Too low
        });

        vm.expectRevert("UniswapV3Facet/min-amount-below-bound");
        vm.prank(RELAYER);
        foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            minAmounts,
            block.timestamp + 1 hours
        );
    }

    // Adding liquidity succeeds when spot price matches TWAP (normal conditions)
    function test_addLiquidityUniswapV3_twapProtection_succeedsWhenPriceMatchesTWAP() external {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        _fundProxy(desired.amount0, desired.amount1);

        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower: initTick - 100,
            upper: initTick + 100
        });

        vm.prank(RELAYER);
        ( uint256 tokenId, uint128 liquidity, ) = foreignController.addLiquidityUniswapV3(
            _getPool(),
            0,
            tick,
            desired,
            _minLiquidityPosition(desired.amount0, desired.amount1),
            block.timestamp + 1 hours
        );

        assertGt(liquidity, 0, "Should successfully add liquidity");
        assertGt(tokenId, 0, "Should mint position NFT");
    }

}

abstract contract UniswapV3_AddLiquidity_E2ETestBase is UniswapV3_TestBase {

    function _addLiquidityAndValidate(
        uint256                      currentTokenId,
        IUniswapV3Facet.Ticks memory tick,
        uint256                      amount0,
        uint256                      amount1,
        bytes32                      token0RateLimitKey,
        bytes32                      token1RateLimitKey
    )
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0Used, uint256 amount1Used)
    {
        uint256 token0RateLimitBefore = rateLimits.getCurrentRateLimit(token0RateLimitKey);
        uint256 token1RateLimitBefore = rateLimits.getCurrentRateLimit(token1RateLimitKey);

        ( tokenId, liquidity, amount0Used, amount1Used ) = _addLiquidity(
            currentTokenId,
            tick,
            IUniswapV3Facet.TokenAmounts({ amount0: amount0, amount1: amount1 }),
            _minLiquidityPosition(amount0, amount1)
        );

        uint256 token0RateLimitAfter = rateLimits.getCurrentRateLimit(token0RateLimitKey);
        uint256 token1RateLimitAfter = rateLimits.getCurrentRateLimit(token1RateLimitKey);

        assertEq(token0RateLimitBefore - token0RateLimitAfter, amount0Used, "token0 rate limit delta mismatch");
        assertEq(token1RateLimitBefore - token1RateLimitAfter, amount1Used, "token1 rate limit delta mismatch");
    }

    function _e2eAddLiquidityUniswapV3(
        uint256 addAmount0,
        uint256 addAmount1,
        int24   lowerTickDelta,
        int24   upperTickDelta,
        bytes32 token0RateLimitKey,
        bytes32 token1RateLimitKey
    )
        internal
    {
        uint256 amount0 = addAmount0;
        uint256 amount1 = addAmount1;

        deal(address(token0), almProxy, amount0);
        deal(address(token1), almProxy, amount1);

        IUniswapV3Facet.Ticks memory tick = IUniswapV3Facet.Ticks({
            lower : initTick + lowerTickDelta,
            upper : initTick + upperTickDelta
        });

        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Used;
        uint256 amount1Used;

        ( tokenId, liquidity, amount0Used, amount1Used ) = _addLiquidityAndValidate(
            0,
            tick,
            amount0,
            amount1,
            token0RateLimitKey,
            token1RateLimitKey
        );

        assertGt(liquidity, 0, "liquidity should be greater than 0");

        assertApproxEqRel(amount0, amount0Used, .05e18, "amount0Used should be within 5% of amount0");
        assertEq(amount1, amount1Used, "amount1Used should be within .05% of amount1");

        vm.warp(block.timestamp + 2 hours); // Advance sufficient time for twap

        amount0 *= 2;
        amount1 *= 2;

        deal(address(token0), almProxy, amount0);
        deal(address(token1), almProxy, amount1);

        ( /* uint256 tokenId */, liquidity, amount0Used, amount1Used ) = _addLiquidityAndValidate(
            tokenId,
            tick,
            amount0,
            amount1,
            token0RateLimitKey,
            token1RateLimitKey
        );

        assertGt(liquidity, 0, "liquidity should be greater than 0");

        assertApproxEqRel(amount0, amount0Used, .05e18, "amount0Used should be within 5% of amount0");
        assertEq(amount1, amount1Used, "amount1Used should be within .05% of amount1");
    }

}

contract ForeignController_UniswapV3_AddLiquidity_AUSDUSDS_E2ETests is UniswapV3_AddLiquidity_E2ETestBase {

    function _getPool() internal view override returns (address) {
        return usdsAusdPool;
    }

    function test_e2e_addLiquidityUniswapV3_equalParts(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        uint256 addAmount0 = addAmount;
        uint256 addAmount1 = addAmount * 10**token1.decimals() / 10**18;

        _e2eAddLiquidityUniswapV3(
            addAmount0,
            addAmount1,
            -100,
            100,
            uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey,
            uniswapV3_AusdUsdsPool_AusdAddLiquidityKey
        );
    }

    function test_e2e_addLiquidityUniswapV3_token0Only(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        addAmount *= 10**token0.decimals() / 10**18;

        _e2eAddLiquidityUniswapV3(
            addAmount,
            0,
            50,
            100,
            uniswapV3_AusdUsdsPool_AusdAddLiquidityKey,
            uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey
        );
    }

    function test_e2e_addLiquidityUniswapV3_token1Only(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        addAmount *= 10**token1.decimals() / 10**18;

        _e2eAddLiquidityUniswapV3(
            0,
            addAmount,
            -100,
            -50,
            uniswapV3_AusdUsdsPool_AusdAddLiquidityKey,
            uniswapV3_AusdUsdsPool_UsdsAddLiquidityKey
        );

    }

}

contract ForeignController_UniswapV3_AddLiquidity_USDSUSDC_E2ETests is UniswapV3_AddLiquidity_E2ETestBase {

    function _getPool() internal view override returns (address) {
        return usdsUsdcPool;
    }

    function test_e2e_addLiquidityUniswapV3_equalParts(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        uint256 addAmount0 = addAmount;
        uint256 addAmount1 = addAmount * 10**token1.decimals() / 10**18;

        _e2eAddLiquidityUniswapV3(
            addAmount0,
            addAmount1,
            -100,
            100,
            uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey,
            uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey
        );
    }

    function test_e2e_addLiquidityUniswapV3_token0Only(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        addAmount *= 10**token0.decimals() / 10**18;

        _e2eAddLiquidityUniswapV3(
            addAmount,
            0,
            50,
            100,
            uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey,
            uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey
        );
    }

    function test_e2e_addLiquidityUniswapV3_token1Only(uint256 addAmount) external {
        addAmount = bound(addAmount, 1e18, 100_000e18);

        addAmount = addAmount * 10**token1.decimals() / 1e18;

        _e2eAddLiquidityUniswapV3(
            0,
            addAmount,
            -100,
            -50,
            uniswapV3_UsdsUsdcPool_UsdsAddLiquidityKey,
            uniswapV3_UsdsUsdcPool_UsdcAddLiquidityKey
        );
    }

}

contract ForeignController_UniswapV3_RemoveLiquidity_FailureTests  is UniswapV3_TestBase {

    uint256 internal tokenId;
    uint128 internal liquidity;
    uint256 internal amount0;
    uint256 internal amount1;

    uint256 internal defaultMinAmount0;
    uint256 internal defaultMinAmount1;

    function setUp() public override {
        super.setUp();

        ( tokenId, liquidity, amount0, amount1 ) = _mintProxyPosition();

        defaultMinAmount0 = amount0 * 98 / 100;
        defaultMinAmount1 = amount1 * 98 / 100;
    }

    function _defaultTickRange() internal view returns (IUniswapV3Facet.Ticks memory) {
        return IUniswapV3Facet.Ticks({ lower: initTick - 50, upper: initTick + 50 });
    }

    function _defaultDesiredPosition() internal view returns (IUniswapV3Facet.TokenAmounts memory) {
        uint8 token1Decimals = IERC20Like(address(token1)).decimals();

        return IUniswapV3Facet.TokenAmounts({
            amount0 : 1_000 * 10 ** uint256(token0Decimals),
            amount1 : 1_000 * 10 ** uint256(token1Decimals)
        });
    }

    function _mintProxyPosition() internal returns (uint256 tokenId_, uint128 liquidity_, uint256 amount0_, uint256 amount1_) {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();
        IUniswapV3Facet.Ticks memory tick = _defaultTickRange();

        deal(address(token0), almProxy, desired.amount0);
        deal(address(token1), almProxy, desired.amount1);

        vm.startPrank(almProxy);

        token0.approve(UNISWAP_V3_POSITION_MANAGER, desired.amount0);
        token1.approve(UNISWAP_V3_POSITION_MANAGER, desired.amount1);

        ( tokenId_, liquidity_, amount0_, amount1_ ) = INonfungiblePositionManagerLike(UNISWAP_V3_POSITION_MANAGER).mint(
            INonfungiblePositionManagerLike.MintParams({
                token0         : address(token0),
                token1         : address(token1),
                fee            : poolFee,
                tickLower      : tick.lower,
                tickUpper      : tick.upper,
                amount0Desired : desired.amount0,
                amount1Desired : desired.amount1,
                amount0Min     : 0,
                amount1Min     : 0,
                recipient      : almProxy,
                deadline       : block.timestamp + 1 hours
            })
        );

        vm.stopPrank();
    }

    function _mintExternalPosition() internal returns (uint256 tokenId_, uint128 liquidity_, uint256 amount0_, uint256 amount1_) {
        IUniswapV3Facet.TokenAmounts memory desired = _defaultDesiredPosition();

        deal(address(token0), stranger, desired.amount0);
        deal(address(token1), stranger, desired.amount1);

        vm.startPrank(stranger);

        token0.approve(UNISWAP_V3_POSITION_MANAGER, desired.amount0);
        token1.approve(UNISWAP_V3_POSITION_MANAGER, desired.amount1);

        ( tokenId_, liquidity_, amount0_, amount1_ ) = INonfungiblePositionManagerLike(UNISWAP_V3_POSITION_MANAGER).mint(
            INonfungiblePositionManagerLike.MintParams({
                token0         : address(token0),
                token1         : address(token1),
                fee            : poolFee,
                tickLower      : initTick - 50,
                tickUpper      : initTick + 50,
                amount0Desired : desired.amount0,
                amount1Desired : desired.amount1,
                amount0Min     : 0,
                amount1Min     : 0,
                recipient      : stranger,
                deadline       : block.timestamp + 1 hours
            })
        );

        vm.stopPrank();
    }

    function test_removeLiquidityUniswapV3_reentrancy() external {
        _setControllerEntered();

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: 0, amount1: 0 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_notRelayer() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlLike.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                RELAYER_ROLE
            )
        );
        vm.prank(unauthorized);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            0,
            1,
            IUniswapV3Facet.TokenAmounts({ amount0: 0, amount1: 0 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_maxSlippageNotSet() external {
        ( uint256 tokenId_, uint128 liquidity_, , ) = _mintExternalPosition();

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3MaxSlippage(_getPool(), 0);

        vm.expectRevert("UniswapV3Facet/max-slippage-not-set");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_proxyDoesNotOwnTokenId() external {
        (uint256 tokenId_, uint128 liquidity_, , ) = _mintExternalPosition();

        vm.warp(block.timestamp + 1 hours);

        vm.expectRevert("UniswapV3Facet/proxy-does-not-own-token-id");
        vm.startPrank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId_,
            liquidity_,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_removeLiquidityUniswapV3_zeroLiquidity() external {
        vm.expectRevert("UniswapV3Facet/liquidity-oob");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            0,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_liquidityTooHigh() external {
        vm.expectRevert("UniswapV3Facet/liquidity-oob");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            type(uint128).max,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_invalidPosition() external {
        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3MaxSlippage(usdsAusdPool, 1_000_000e18);

        vm.expectRevert("UniswapV3Facet/invalid-pool");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            usdsAusdPool,
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_feeMismatch() external {
        address mismatchedFeePool = _createPool(address(token0), address(token1), 500);

        vm.prank(Base.SPARK_EXECUTOR);
        foreignController.setUniswapV3MaxSlippage(mismatchedFeePool, 1_000_000e18);

        vm.expectRevert("UniswapV3Facet/invalid-pool");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            mismatchedFeePool,
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_rateLimitExceeded_token0() external {
        vm.startPrank(Base.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey, 1, 0);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey, 1, 0);
        vm.stopPrank();

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

    function test_removeLiquidityUniswapV3_rateLimitExceeded_token1() external {
        vm.startPrank(Base.SPARK_EXECUTOR);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey, 1, 0);
        rateLimits.setRateLimitData(uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey, 1, 0);
        vm.stopPrank();

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(RELAYER);
        foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId,
            liquidity,
            IUniswapV3Facet.TokenAmounts({ amount0: defaultMinAmount0, amount1: defaultMinAmount1 }),
            block.timestamp + 1 hours
        );
    }

}

abstract contract UniswapV3_RemoveLiquidity_E2ETestBase is UniswapV3_TestBase {

    uint256 internal tokenId;
    uint128 internal totalLiquidity;
    uint256 internal amount0Added;
    uint256 internal amount1Added;

    function setUp() public override {
        super.setUp();

        uint256 addAmount = 1_000_000e18;

        uint256 addAmount0 = addAmount;
        uint256 addAmount1 = addAmount * 10**token1.decimals() / 10**18;

        ( tokenId, totalLiquidity, amount0Added, amount1Added ) = _addLiquidity(
            addAmount0,
            addAmount1,
            IUniswapV3Facet.Ticks({lower : -100, upper : 100})
        );
    }

    function _addLiquidity(uint256 addAmount0, uint256 addAmount1, IUniswapV3Facet.Ticks memory addTickDelta)
        internal
        returns (uint256 tokenId_, uint128 liquidity_, uint256 amount0Used_, uint256 amount1Used_)
    {
        deal(address(token0), almProxy, addAmount0);
        deal(address(token1), almProxy, addAmount1);

        ( tokenId_, liquidity_, amount0Used_, amount1Used_ ) = _addLiquidity(
            0,
            IUniswapV3Facet.Ticks({
                lower : initTick + addTickDelta.lower,
                upper : initTick + addTickDelta.upper
            }),
            IUniswapV3Facet.TokenAmounts({ amount0: addAmount0, amount1: addAmount1 }),
            _minLiquidityPosition(addAmount0, addAmount1)
        );

        vm.warp(block.timestamp + 2 hours); // Advance sufficient time for twap
    }

    function _removeLiquidityAndValidate(
        uint256 tokenId_,
        uint128 liquidity_,
        uint256 minAmount0_,
        uint256 minAmount1_,
        bytes32 token0RateLimitKey_,
        bytes32 token1RateLimitKey_
    ) internal returns (uint256 amount0Used, uint256 amount1Used) {
        uint256 token0RateLimitBefore = rateLimits.getCurrentRateLimit(token0RateLimitKey_);
        uint256 token1RateLimitBefore = rateLimits.getCurrentRateLimit(token1RateLimitKey_);

        vm.prank(RELAYER);
        IUniswapV3Facet.TokenAmounts memory amountsUsed = foreignController.removeLiquidityUniswapV3(
            _getPool(),
            tokenId_,
            liquidity_,
            IUniswapV3Facet.TokenAmounts({ amount0: minAmount0_, amount1: minAmount1_ }),
            block.timestamp + 1 hours
        );

        amount0Used = amountsUsed.amount0;
        amount1Used = amountsUsed.amount1;

        assertGe(amount0Used, minAmount0_, "amount0Used should be greater than or equal to minAmount0");
        assertGe(amount1Used, minAmount1_, "amount1Used should be greater than or equal to minAmount1");

        assertApproxEqRel(
            amount0Used,
            amount0Added * liquidity_ / totalLiquidity,
            0.0001e18,
            "amount0Used should be within 0.01% of amount0Added * liquidity / totalLiquidity"
        );

        assertApproxEqRel(
            amount1Used,
            amount1Added * liquidity_ / totalLiquidity,
            0.0001e18,
            "amount1Used should be within 0.01% of amount1Added * liquidity / totalLiquidity"
        );

        uint256 token0RateLimitAfter = rateLimits.getCurrentRateLimit(token0RateLimitKey_);
        uint256 token1RateLimitAfter = rateLimits.getCurrentRateLimit(token1RateLimitKey_);

        assertApproxEqAbs(token0RateLimitBefore - token0RateLimitAfter, amount0Used, 1, "token0 rate limit delta mismatch");
        assertApproxEqAbs(token1RateLimitBefore - token1RateLimitAfter, amount1Used, 1, "token1 rate limit delta mismatch");
    }

}

contract ForeignController_UniswapV3_RemoveLiquidity_AUSDUSDS_E2ETests is UniswapV3_RemoveLiquidity_E2ETestBase {

    function _getPool() internal view override returns (address) {
        return usdsAusdPool;
    }

    function test_e2e_addRemoveLiquidityUniswapV3_ausdUsds(uint128 liquidity) external {
        liquidity = uint128(bound(uint256(liquidity), 1000000, uint256(totalLiquidity)));

        uint256 minAmount0 = amount0Added * liquidity / totalLiquidity;
        uint256 minAmount1 = amount1Added * liquidity / totalLiquidity;

        _removeLiquidityAndValidate(
            tokenId,
            liquidity,
            minAmount0 * 9999/10000,
            minAmount1 * 9999/10000,
            uniswapV3_AusdUsdsPool_AusdRemoveLiquidityKey,
            uniswapV3_AusdUsdsPool_UsdsRemoveLiquidityKey
        );
    }

    function test_e2e_removeLiquidityUniswapV3_ausdUsds_allLiquidity() external {
        _removeLiquidityAndValidate(
            tokenId,
            totalLiquidity,
            amount0Added * 9999/10000,
            amount1Added * 9999/10000,
            uniswapV3_AusdUsdsPool_AusdRemoveLiquidityKey,
            uniswapV3_AusdUsdsPool_UsdsRemoveLiquidityKey
        );
    }

}

contract ForeignController_UniswapV3_RemoveLiquidity_USDSUSDC_E2ETests is UniswapV3_RemoveLiquidity_E2ETestBase {

    function _getPool() internal view override returns (address) {
        return usdsUsdcPool;
    }

    function test_e2e_addRemoveLiquidityUniswapV3_usdsUsdc(uint128 liquidity) external {
        liquidity = uint128(bound(uint256(liquidity), 1000000, uint256(totalLiquidity)));

        uint256 minAmount0 = amount0Added * liquidity / totalLiquidity;
        uint256 minAmount1 = amount1Added * liquidity / totalLiquidity;

        _removeLiquidityAndValidate(
            tokenId,
            liquidity,
            minAmount0 * 9999/10000,
            minAmount1 * 9999/10000,
            uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey,
            uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey
        );
    }

    function test_e2e_removeLiquidityUniswapV3_usdsUsdc_allLiquidity() external {
        _removeLiquidityAndValidate(
            tokenId,
            totalLiquidity,
            amount0Added * 9999/10000,
            amount1Added * 9999/10000,
            uniswapV3_UsdsUsdcPool_UsdsRemoveLiquidityKey,
            uniswapV3_UsdsUsdcPool_UsdcRemoveLiquidityKey
        );
    }

}
