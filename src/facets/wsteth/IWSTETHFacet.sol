// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IWSTETHFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when a withdrawal is claimed.
     * @param requestId   Request ID.
     * @param wethClaimed Amount of WETH claimed.
     */
    event WSTETHClaimWithdrawal(uint256 indexed requestId, uint256 wethClaimed);

    /**
     * @dev   Event emitted when WSTETH is deposited.
     * @param amount Amount of WSTETH deposited.
     */
    event WSTETHDeposit(uint256 amount);

    /**
     * @dev   Event emitted when a withdrawal is requested.
     * @param amountToRedeem Amount of WSTETH to redeem.
     * @param stethAmount    Amount of stETH.
     * @param requestIds     Request IDs.
     */
    event WSTETHRequestWithdraw(uint256 amountToRedeem, uint256 stethAmount, uint256[] requestIds);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Claims a withdrawal.
     * @param requestId Request ID.
     */
    function claimWithdrawal(uint256 requestId) external;

    /**
     * @dev   Deposits WSTETH.
     * @param amount Amount of WSTETH to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev    Requests a withdrawal.
     * @param  amountToRedeem Amount of WSTETH to redeem.
     * @return requestIds Request IDs.
     */
    function requestWithdraw(uint256 amountToRedeem) external returns (uint256[] memory requestIds);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for request withdrawal operations.
     * @return bytes32 Key for request withdrawal limit.
     */
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    WETH contract address.
     * @return address WETH contract address.
     */
    function weth() external view returns (address);

    /**
     * @dev    Withdraw queue contract address.
     * @return address Withdraw queue contract address.
     */
    function withdrawQueue() external view returns (address);

    /**
     * @dev    WSTETH contract address.
     * @return address WSTETH contract address.
     */
    function wsteth() external view returns (address);

}
