// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IWSTETHFacet
 * @notice DiamondPAU facet for interacting with Lido's wstETH. Supports
 *         depositing WETH to receive wstETH, requesting stETH withdrawals
 *         via the Lido withdrawal queue, and claiming completed withdrawals.
 */
interface IWSTETHFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when a withdrawal is claimed from the Lido queue.
     * @param requestId   ID of the withdrawal request being claimed.
     * @param wethClaimed Amount of WETH received (ETH claimed and wrapped).
     */
    event WSTETHClaimWithdrawal(uint256 indexed requestId, uint256 wethClaimed);

    /**
     * @dev   Emitted when WETH is deposited to receive wstETH. Unwraps WETH to ETH and sends
     *        to the wstETH contract.
     * @param amount Amount of WETH deposited.
     */
    event WSTETHDeposit(uint256 amount);

    /**
     * @dev   Emitted when a withdrawal is requested from the Lido queue.
     * @param amountToRedeem Amount of wstETH submitted for withdrawal.
     * @param stethAmount    Equivalent stETH amount at the time of request.
     * @param requestIds     IDs of the created withdrawal requests.
     */
    event WSTETHRequestWithdraw(uint256 amountToRedeem, uint256 stethAmount, uint256[] requestIds);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Claims a completed withdrawal from the Lido queue.
     *        The received ETH is automatically wrapped to WETH.
     * @param requestId ID of the withdrawal request to claim.
     */
    function claimWithdrawal(uint256 requestId) external;

    /**
     * @dev   Deposits WETH to receive wstETH. Unwraps WETH to ETH and sends
     *        it to the wstETH contract.
     * @param amount Amount of WETH to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @dev    Requests a withdrawal of wstETH via the Lido withdrawal queue.
     *         Rate limited by the equivalent stETH amount.
     * @param  amountToRedeem Amount of wstETH to submit for withdrawal.
     * @return requestIds     IDs of the created withdrawal requests.
     */
    function requestWithdraw(uint256 amountToRedeem) external returns (uint256[] memory requestIds);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for wstETH deposit operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for wstETH withdrawal request operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Address of the WETH token contract (immutable).
     * @return address The WETH contract address.
     */
    function weth() external view returns (address);

    /**
     * @dev    Address of the Lido withdrawal queue contract (immutable).
     * @return address The withdrawal queue contract address.
     */
    function withdrawQueue() external view returns (address);

    /**
     * @dev    Address of the wstETH token contract (immutable).
     * @return address The wstETH contract address.
     */
    function wsteth() external view returns (address);

}