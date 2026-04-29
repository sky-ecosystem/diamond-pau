// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ICurveFacet
 * @notice PAU facet for interacting with Curve pools. Supports adding and removing liquidity, and
 *         token swaps. All value calculations use 18-decimal normalized USD amounts derived from
 *         Curve stored_rates.
 */
interface ICurveFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when liquidity is added to a Curve pool.
     * @param  pool           Address of the Curve pool.
     * @param  shares         Amount of LP tokens received.
     * @param  valueDeposited Aggregate deposited value, 18-decimal normalized USD.
     * @param  depositAmounts Per-token amounts deposited (native token decimals).
     */
    event CurveAddLiquidity(
        address   indexed pool,
        uint256           shares,
        uint256           valueDeposited,
        uint256[]         depositAmounts
    );

    /**
     * @notice Emitted when the deposit rate limit is set.
     * @param  key  Rate limit key.
     * @param  pool Address of the Curve pool.
     */
    event CurveDepositRateLimitSet(bytes32 indexed key, address indexed pool);

    /**
     * @notice Emitted when the max slippage for a Curve pool is updated.
     * @param  pool        Address of the Curve pool.
     * @param  maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event CurveMaxSlippageSet(address indexed pool, uint256 maxSlippage);

    /**
     * @notice Emitted when liquidity is removed from a Curve pool.
     * @param  pool            Address of the Curve pool.
     * @param  lpBurnAmount    Amount of LP tokens burned.
     * @param  valueWithdrawn  Aggregate withdrawn value, 18-decimal normalized USD.
     * @param  withdrawnTokens Per-token amounts withdrawn (native token decimals).
     */
    event CurveRemoveLiquidity(
        address   indexed pool,
        uint256           lpBurnAmount,
        uint256           valueWithdrawn,
        uint256[]         withdrawnTokens
    );

    /**
     * @notice Emitted when a token swap is executed on a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @param  inputIndex  Index of the input token in the pool.
     * @param  outputIndex Index of the output token in the pool.
     * @param  amountIn    Amount of input tokens swapped (native decimals).
     * @param  amountOut   Amount of output tokens received (native decimals).
     */
    event CurveSwap(
        address indexed pool,
        uint256 indexed inputIndex,
        uint256 indexed outputIndex,
        uint256         amountIn,
        uint256         amountOut
    );

    /**
     * @notice Emitted when the swap rate limit is set.
     * @param  key  Rate limit key.
     * @param  pool Address of the Curve pool.
     */
    event CurveSwapRateLimitSet(bytes32 indexed key, address indexed pool);

    /**
     * @notice Emitted when the withdraw rate limit is set.
     * @param  key  Rate limit key.
     * @param  pool Address of the Curve pool.
     */
    event CurveWithdrawRateLimitSet(bytes32 indexed key, address indexed pool);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Adds liquidity to a Curve pool.
     * @param  pool           Address of the Curve pool.
     * @param  depositAmounts Per-token amounts to deposit (native token decimals).
     * @param  minLpAmount    Minimum LP tokens to receive.
     * @return shares         Amount of LP tokens received.
     */
    function addLiquidity(address pool, uint256[] calldata depositAmounts, uint256 minLpAmount)
        external
        returns (uint256 shares);

    /**
     * @notice Removes liquidity from a Curve pool proportionally.
     * @param  pool               Address of the Curve pool.
     * @param  lpBurnAmount       Amount of LP tokens to burn.
     * @param  minWithdrawAmounts Per-token minimum amounts to receive.
     * @return withdrawnTokens    Per-token amounts actually withdrawn.
     */
    function removeLiquidity(
        address            pool,
        uint256            lpBurnAmount,
        uint256[] calldata minWithdrawAmounts
    )
        external
        returns (uint256[] memory withdrawnTokens);

    /**
     * @notice Sets the deposit rate limit for a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the max slippage for a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @param  maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address pool, uint256 maxSlippage) external;

    /**
     * @notice Sets the swap rate limit for a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setSwapRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the withdraw rate limit for a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Swaps tokens within a Curve pool.
     * @param  pool         Address of the Curve pool.
     * @param  inputIndex   Index of the input token in the pool.
     * @param  outputIndex  Index of the output token in the pool.
     * @param  amountIn     Amount of input tokens to swap (native decimals).
     * @param  minAmountOut Minimum output tokens to receive (native decimals).
     * @return amountOut    Actual amount of output tokens received.
     */
    function swap(
        address pool,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for swap operations.
    function LIMIT_SWAP() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the deposit rate limit for a Curve pool.
     * @param  pool Address of the Curve pool.
     * @return data Rate limit data.
     */
    function getDepositRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the configured max slippage for a Curve pool.
     * @param  pool        Address of the Curve pool.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address pool) external view returns (uint256 maxSlippage);

    /**
     * @notice Returns the swap rate limit for a Curve pool.
     * @param  pool Address of the Curve pool.
     * @return data Rate limit data.
     */
    function getSwapRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the withdraw rate limit for a Curve pool.
     * @param  pool Address of the Curve pool.
     * @return data Rate limit data.
     */
    function getWithdrawRateLimit(address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
