// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IAaveFacet
 * @notice PAU facet for supplying and withdrawing assets via Aave V3 lending pools.
 */
interface IAaveFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an underlying asset is supplied to an Aave pool.
     * @param  aToken Address of the aToken representing the Aave market.
     * @param  amount Amount of underlying asset deposited.
     */
    event AaveDeposit(address indexed aToken, uint256 amount);

    /**
     * @notice Emitted when the deposit rate limit for an aToken market is updated.
     * @param  key             Derived key of the rate limit.
     * @param  aToken          Address of the aToken.
     * @param  underlyingAsset Address of the underlying asset.
     */
    event AaveDepositRateLimitSet(
        bytes32 indexed key,
        address indexed aToken,
        address         pool,
        address         underlyingAsset
    );

    /**
     * @notice Emitted when the max slippage for an aToken market is updated.
     * @param  aToken      Address of the aToken.
     * @param  maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage);

    /**
     * @notice Emitted when underlying assets are withdrawn from an Aave pool.
     * @param  aToken          Address of the aToken representing the Aave market.
     * @param  amountWithdrawn Actual amount of underlying asset withdrawn.
     */
    event AaveWithdraw(address indexed aToken, uint256 amountWithdrawn);

    /**
     * @notice Emitted when the withdraw rate limit for an aToken market is updated.
     * @param  key    Derived key of the rate limit.
     * @param  aToken Address of the aToken.
     * @param  pool   Address of the pool.
     */
    event AaveWithdrawRateLimitSet(bytes32 indexed key, address indexed aToken, address pool);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Supplies underlying asset into the Aave pool for `aToken`.
     * @param  aToken Address of the aToken (determines pool and underlying).
     * @param  amount Amount of underlying asset to supply.
     */
    function deposit(address aToken, uint256 amount) external;

    /**
     * @notice Sets the deposit rate limit for an Aave aToken, pool, and underlying asset.
     * @param  aToken          Address of the aToken.
     * @param  pool            Address of the pool.
     * @param  underlyingAsset Address of the underlying asset.
     * @param  maxAmount       Maximum amount of the rate limit.
     * @param  slope           Slope of the rate limit.
     * @param  lastAmount      Last amount of the rate limit.
     * @param  lastUpdated     Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address aToken,
        address pool,
        address underlyingAsset,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the max slippage for deposit operations on a given aToken.
     * @param  aToken      Address of the aToken.
     * @param  maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address aToken, uint256 maxSlippage) external;

    /**
     * @notice Sets the withdraw rate limit for an Aave aToken and pool.
     * @param  aToken      Address of the aToken.
     * @param  pool        Address of the pool.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address aToken,
        address pool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Withdraws underlying assets from the Aave pool by redeeming aTokens.
     * @param  aToken          Address of the aToken (determines pool and underlying).
     * @param  amount          Amount of underlying asset to withdraw.
     * @return amountWithdrawn Actual amount of underlying withdrawn.
     */
    function withdraw(address aToken, uint256 amount) external returns (uint256 amountWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured deposit rate limit for a given Aave aToken, pool, and
     *         underlying asset.
     * @param  aToken          Address of the aToken.
     * @param  pool            Address of the pool.
     * @param  underlyingAsset Address of the underlying asset.
     * @return data            Rate limit data.
     */
    function getDepositRateLimit(address aToken, address pool, address underlyingAsset)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the configured max slippage for a given aToken market.
     * @param  aToken      Address of the aToken.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address aToken) external view returns (uint256 maxSlippage);

    /**
     * @notice Returns the configured withdraw rate limit for a given Aave aToken and pool.
     * @param  aToken Address of the aToken.
     * @param  pool   Address of the pool.
     * @return data   Rate limit data.
     */
    function getWithdrawRateLimit(address aToken, address pool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
