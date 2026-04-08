// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IPSM3Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a deposit is made.
     * @param asset  Asset address.
     * @param amount Amount of asset deposited.
     * @param shares Amount of shares received.
     */
    event PSM3Deposit(address indexed asset, uint256 amount, uint256 shares);

    /**
     * @dev   Event emitted when a withdrawal is made.
     * @param asset           Asset address.
     * @param assetsWithdrawn Amount of assets withdrawn.
     * @param sharesBurnt     Amount of shares burnt.
     */
    event PSM3Withdraw(address indexed asset, uint256 assetsWithdrawn, uint256 sharesBurnt);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Deposits `amount` of `asset` into the PSM.
     * @param  asset  Asset address.
     * @param  amount Amount of `asset` to deposit.
     * @return shares Amount of shares received.
     */
    function deposit(address asset, uint256 amount) external returns (uint256 shares);

    /**
     * @dev    Withdraws `maxAmount` of `asset` from the PSM.
     * @param  asset           Asset address.
     * @param  maxAmount       Maximum amount of `asset` to withdraw.
     * @return assetsWithdrawn Amount of `asset` withdrawn.
     */
    function withdraw(address asset, uint256 maxAmount) external returns (uint256 assetsWithdrawn);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for withdraw operations.
     * @return bytes32 Key for withdraw limit.
     */
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    PSM contract address.
     * @return address PSM contract address.
     */
    function psm() external view returns (address);

}
