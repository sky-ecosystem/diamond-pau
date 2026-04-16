// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IAaveFacet
 * @notice PAU facet for supplying, withdrawing, borrowing and repaying assets via Aave V3 lending
 *         pools.
 */
interface IAaveFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an underlying asset is borrowed from an Aave pool.
     * @param  aToken          Address of the aToken representing the Aave market.
     * @param  amountReceived  Amount of underlying asset received.
     * @param  newHealthFactor New health factor after borrow (1e18 precision).
     */
    event AaveBorrow(address indexed aToken, uint256 amountReceived, uint256 newHealthFactor);

    /**
     * @notice Emitted when the collateral flag for an aToken market is toggled.
     * @param  aToken          Address of the aToken representing the Aave market.
     * @param  useAsCollateral Whether the asset is enabled as collateral.
     */
    event AaveCollateralSet(address indexed aToken, bool useAsCollateral);

    /**
     * @notice Emitted when an underlying asset is supplied to an Aave pool.
     * @param  aToken Address of the aToken representing the Aave market.
     * @param  amount Amount of underlying asset deposited.
     */
    event AaveDeposit(address indexed aToken, uint256 amount);

    /**
     * @notice Emitted when the max slippage for an aToken market is updated.
     * @param  aToken      Address of the aToken.
     * @param  maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage);

    /**
     * @notice Emitted when borrowed debt is repaid on an Aave pool.
     * @param  aToken       Address of the aToken representing the Aave market.
     * @param  amountRepaid Actual amount of underlying asset repaid.
     */
    event AaveRepay(address indexed aToken, uint256 amountRepaid);

    /**
     * @notice Emitted when underlying assets are withdrawn from an Aave pool.
     * @param  aToken          Address of the aToken representing the Aave market.
     * @param  amountWithdrawn Actual amount of underlying asset withdrawn.
     */
    event AaveWithdraw(address indexed aToken, uint256 amountWithdrawn);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Borrows underlying asset from Aave against the proxy's collateral.
     * @param  aToken          Address of the aToken (determines pool and underlying).
     * @param  amount          Amount of underlying asset to borrow.
     * @param  minHealthFactor Minimum acceptable health factor after borrow (1e18 precision).
     * @return amountReceived  Actual amount of underlying asset received.
     */
    function borrow(address aToken, uint256 amount, uint256 minHealthFactor)
        external
        returns (uint256 amountReceived);

    /**
     * @notice Supplies underlying asset into the Aave pool for `aToken`.
     * @param  aToken Address of the aToken (determines pool and underlying).
     * @param  amount Amount of underlying asset to supply.
     */
    function deposit(address aToken, uint256 amount) external;

    /**
     * @notice Repays borrowed debt on an Aave pool.
     * @param  aToken       Address of the aToken (determines pool and underlying).
     * @param  amount       Amount of underlying to repay (type(uint256).max for full repayment).
     * @return amountRepaid Actual amount of underlying repaid.
     */
    function repay(address aToken, uint256 amount) external returns (uint256 amountRepaid);

    /**
     * @notice Toggles whether a supplied asset is used as collateral in Aave.
     * @param  aToken          Address of the aToken (determines pool and underlying).
     * @param  useAsCollateral True to enable, false to disable.
     */
    function setCollateral(address aToken, bool useAsCollateral) external;

    /**
     * @notice Sets the max slippage for deposit operations on a given aToken.
     * @param  aToken      Address of the aToken.
     * @param  maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address aToken, uint256 maxSlippage) external;

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

    /**
     * @notice Rate limit key for Aave borrow operations, combined with the aToken address to form
     *         the per-market key.
     */
    function LIMIT_BORROW() external pure returns (bytes32);

    /**
     * @notice Rate limit key for Aave deposit operations, combined with the aToken address to form
     *         the per-market key.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @notice Rate limit key for Aave repay operations, combined with the aToken address to form
     *         the per-market key.
     */
    function LIMIT_REPAY() external pure returns (bytes32);

    /**
     * @notice Rate limit key for Aave withdraw operations, combined with the aToken address to form
     *         the per-market keys.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured max slippage for a given aToken market.
     * @param  aToken      Address of the aToken.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address aToken) external view returns (uint256 maxSlippage);

}
