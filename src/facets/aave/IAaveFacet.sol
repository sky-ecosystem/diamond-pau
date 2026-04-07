// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IAaveFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event AaveDeposit(address indexed aToken, uint256 amount);

    /**
     * @dev   Event emitted when max slippage is set.
     * @param aToken      Address of aToken.
     * @param maxSlippage Max slippage allowed.
     */
    event AaveMaxSlippageSet(address indexed aToken, uint256 maxSlippage);

    event AaveWithdraw(address indexed aToken, uint256 amountWithdrawn);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Deposits `amount` of underlying asset into Aave.
     * @param aToken    Address of aToken.
     * @param amount    Amount of underlying asset to deposit.
     */
    function deposit(address aToken, uint256 amount) external;

    /**
     * @dev   Sets max slippage for aToken.
     * @param aToken      Address of aToken.
     * @param maxSlippage Max slippage allowed.
     */
    function setMaxSlippage(address aToken, uint256 maxSlippage) external;

    /**
     * @dev    Withdraws `amount` of underlying asset from Aave.
     * @param  aToken    Address of aToken.
     * @param  amount    Amount of underlying asset to withdraw.
     * @return amountWithdrawn Amount of underlying asset withdrawn.
     */
    function withdraw(address aToken, uint256 amount) external returns (uint256 amountWithdrawn);

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

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @dev    Gets max slippage for aToken.
     * @param  aToken Address of aToken.
     * @return maxSlippage Max slippage allowed.
     */
    function getMaxSlippage(address aToken) external view returns (uint256);

}
