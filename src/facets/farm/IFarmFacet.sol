// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IFarmFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when tokens are deposited to a farm.
     * @param farmToken Farm token address.
     * @param amount    Amount of tokens deposited.
     */
    event FarmDeposit(address indexed farmToken, uint256 amount);

    /**
     * @dev   Event emitted when tokens are withdrawn from a farm.
     * @param farmToken Farm token address.
     * @param amount    Amount of tokens withdrawn.
     */
    event FarmWithdraw(address indexed farmToken, uint256 amount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Deposits `amount` of tokens to a farm.
     * @param farm   Farm address.
     * @param amount Amount of tokens to deposit.
     */
    function deposit(address farm, uint256 amount) external;

    /**
     * @dev   Withdraws `amount` of tokens from a farm.
     * @param farm   Farm address.
     * @param amount Amount of tokens to withdraw.
     */
    function withdraw(address farm, uint256 amount) external;

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

}
