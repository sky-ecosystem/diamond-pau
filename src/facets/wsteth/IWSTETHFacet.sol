// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IWSTETHFacet
 * @notice PAU facet for interacting with Lido's wstETH. Supports depositing WETH to receive wstETH,
 *         requesting stETH withdrawals via the Lido withdrawal queue, and claiming completed
 *         withdrawals.
 */
interface IWSTETHFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a withdrawal is claimed from the Lido queue.
     * @param  requestId   ID of the withdrawal request being claimed.
     * @param  wethClaimed Amount of WETH received (ETH claimed and wrapped).
     */
    event WSTETHClaimWithdrawal(uint256 indexed requestId, uint256 wethClaimed);

    /**
     * @notice Emitted when WETH is deposited to receive wstETH. Unwraps WETH to ETH and sends
     *         to the wstETH contract.
     * @param  amount Amount of WETH deposited.
     */
    event WSTETHDeposit(uint256 amount);

    /**
     * @notice Emitted when the deposit rate limit is set.
     * @param  key Rate limit key.
     */
    event WSTETHDepositRateLimitSet(bytes32 indexed key);

    /**
     * @notice Emitted when a withdrawal is requested from the Lido queue.
     * @param  amountToRedeem Amount of wstETH submitted for withdrawal.
     * @param  stethAmount    Equivalent stETH amount at the time of request.
     * @param  requestIds     IDs of the created withdrawal requests.
     */
    event WSTETHRequestWithdraw(uint256 amountToRedeem, uint256 stethAmount, uint256[] requestIds);

    /**
     * @notice Emitted when the request withdraw rate limit is set.
     * @param  key Rate limit key.
     */
    event WSTETHRequestWithdrawRateLimitSet(bytes32 indexed key);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Claims a completed withdrawal from the Lido queue. The received ETH is automatically
     *         wrapped to WETH.
     * @param  requestId ID of the withdrawal request to claim.
     */
    function claimWithdrawal(uint256 requestId) external;

    /**
     * @notice Deposits WETH to receive wstETH. Unwraps WETH to ETH and sends it to the wstETH
     *         contract.
     * @param  amount Amount of WETH to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Requests a withdrawal of wstETH via the Lido withdrawal queue. Rate limited by the
     *         equivalent stETH amount.
     * @param  amountToRedeem Amount of wstETH to submit for withdrawal.
     * @return requestIds     IDs of the created withdrawal requests.
     */
    function requestWithdraw(uint256 amountToRedeem) external returns (uint256[] memory requestIds);

    /**
     * @notice Sets the deposit rate limit.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the request withdraw rate limit.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setRequestWithdrawRateLimit(
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key for withdrawal request operations.
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /**
     * @notice Returns the deposit rate limit.
     * @return data Rate limit data.
     */
    function depositRateLimit() external view returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the request withdraw rate limit.
     * @return data Rate limit data.
     */
    function requestWithdrawRateLimit()
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /// @notice Address of the WETH token contract (immutable).
    function weth() external view returns (address);

    /// @notice Address of the Lido withdrawal queue contract (immutable).
    function withdrawQueue() external view returns (address);

    /// @notice Address of the wstETH token contract (immutable).
    function wsteth() external view returns (address);

}
