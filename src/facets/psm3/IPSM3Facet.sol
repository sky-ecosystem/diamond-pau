// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IPSM3Facet
 * @notice DiamondPAU facet for depositing into and withdrawing from the Spark
 *         PSM3 (multi-asset Peg Stability Module).
 */
interface IPSM3Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when an asset is deposited into the PSM.
     * @param asset  Address of the deposited asset token.
     * @param amount Amount of asset deposited (native token decimals).
     * @param shares Amount of PSM shares received.
     */
    event PSM3Deposit(address indexed asset, uint256 amount, uint256 shares);

    /**
     * @dev   Emitted when an asset is withdrawn from the PSM.
     * @param asset           Address of the withdrawn asset token.
     * @param assetsWithdrawn Actual amount of asset withdrawn (native decimals).
     * @param sharesBurnt     Amount of PSM shares burned.
     */
    event PSM3Withdraw(address indexed asset, uint256 assetsWithdrawn, uint256 sharesBurnt);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Deposits an asset into the PSM.
     * @param  asset  Address of the asset to deposit.
     * @param  amount Amount of asset to deposit (native token decimals).
     * @return shares Amount of PSM shares received.
     */
    function deposit(address asset, uint256 amount) external returns (uint256 shares);

    /**
     * @dev    Withdraws an asset from the PSM up to `maxAmount`.
     * @param  asset           Address of the asset to withdraw.
     * @param  maxAmount       Maximum amount of asset to withdraw (native decimals).
     * @return assetsWithdrawn Actual amount of asset withdrawn.
     */
    function withdraw(address asset, uint256 maxAmount) external returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for PSM deposit operations, combined with the
     *         asset address to form per-asset keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for PSM withdraw operations, combined with the
     *         asset address to form per-asset keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Address of the PSM3 contract (immutable).
     * @return address The PSM contract address.
     */
    function psm() external view returns (address);

}