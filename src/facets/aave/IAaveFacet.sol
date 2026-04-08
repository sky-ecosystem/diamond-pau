// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IAaveFacet
 * @notice DiamondPAU facet for supplying and withdrawing assets via Aave V3 lending pools.
 */
interface IAaveFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when an underlying asset is supplied to an Aave pool.
     * @param aToken Address of the aToken representing the Aave market.
     * @param amount Amount of underlying asset deposited.
     */
    event AaveDeposit(address indexed aToken, uint256 amount);

    /**
     * @dev   Emitted when the max slippage for an aToken market is updated.
     * @param aToken      Address of the aToken.
     * @param maxSlippage New max slippage in 1e18 precision (1e18 = no slippage).
     */
    event AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage);

    /**
     * @dev   Emitted when underlying assets are withdrawn from an Aave pool.
     * @param aToken          Address of the aToken representing the Aave market.
     * @param amountWithdrawn Actual amount of underlying asset withdrawn.
     */
    event AaveWithdraw(address indexed aToken, uint256 amountWithdrawn);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Supplies underlying asset into the Aave pool for `aToken`.
     * @param aToken Address of the aToken (determines pool and underlying).
     * @param amount Amount of underlying asset to supply.
     */
    function deposit(address aToken, uint256 amount) external;

    /**
     * @dev   Sets the max slippage for deposit operations on a given aToken.
     * @param aToken      Address of the aToken.
     * @param maxSlippage Max slippage in 1e18 precision (1e18 = no slippage).
     */
    function setMaxSlippage(address aToken, uint256 maxSlippage) external;

    /**
     * @dev    Withdraws underlying assets from the Aave pool by redeeming aTokens.
     * @param  aToken          Address of the aToken (determines pool and underlying).
     * @param  amount          Amount of underlying asset to withdraw.
     * @return amountWithdrawn Actual amount of underlying withdrawn.
     */
    function withdraw(address aToken, uint256 amount) external returns (uint256 amountWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for Aave deposit operations, combined with the
     *         aToken address to form the per-market key.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for Aave withdraw operations, combined with the
     *         aToken address to form the per-market key.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Returns the configured max slippage for a given aToken market.
     * @param  aToken      Address of the aToken.
     * @return maxSlippage Max slippage in 1e18 precision. Zero means not set.
     */
    function getMaxSlippage(address aToken) external view returns (uint256);

}
