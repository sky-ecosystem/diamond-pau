// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IWEETHFacet
 * @notice PAU facet for interacting with EtherFi's weETH. Supports depositing WETH to receive weETH
 *         (via eETH wrapping), requesting withdrawals back to ETH, and claiming completed
 *         withdrawals.
 */
interface IWEETHFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a withdrawal is claimed from a weETH module.
     * @param  weethModule Address of the weETH withdrawal module.
     * @param  requestId   ID of the withdrawal request being claimed.
     * @param  ethReceived Amount of ETH received from the claim.
     */
    event WEETHClaimWithdrawal(
        address indexed weethModule,
        uint256 indexed requestId,
        uint256         ethReceived
    );

    /**
     * @notice Emitted when WETH is deposited to receive weETH.
     * @param  amount     Amount of WETH deposited.
     * @param  eethAmount Amount of eETH received (intermediate step).
     * @param  shares     Amount of weETH shares received.
     */
    event WEETHDeposit(uint256 amount, uint256 eethAmount, uint256 shares);

    /**
     * @notice Emitted when the deposit rate limit is set.
     * @param  key           Rate limit key.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     */
    event WEETHDepositRateLimitSet(bytes32 indexed key, address eeth, address liquidityPool);

    /**
     * @notice Emitted when an ETH withdrawal is requested from weETH.
     * @param  weethModule Address of the weETH withdrawal module.
     * @param  requestId   ID of the created withdrawal request.
     * @param  eethAmount  Amount of eETH submitted for withdrawal.
     * @param  weethShares Amount of weETH shares unwrapped.
     */
    event WEETHRequestWithdraw(
        address indexed weethModule,
        uint256 indexed requestId,
        uint256         eethAmount,
        uint256         weethShares
    );

    /**
     * @notice Emitted when the request withdraw rate limit is set.
     * @param  key           Rate limit key.
     * @param  weethModule   Address of the weETH withdrawal module.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     */
    event WEETHRequestWithdrawRateLimitSet(
        bytes32 indexed key,
        address indexed weethModule,
        address         eeth,
        address         liquidityPool
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Claims a completed withdrawal from a weETH module.
     * @param  weethModule Address of the weETH withdrawal module.
     * @param  requestId   ID of the withdrawal request to claim.
     * @return ethReceived Amount of ETH received.
     */
    function claimWithdrawal(address weethModule, uint256 requestId)
        external
        returns (uint256 ethReceived);

    /**
     * @notice Deposits WETH to receive weETH. Unwraps WETH to ETH, deposits into EtherFi liquidity
     *         pool for eETH, then wraps eETH to weETH.
     * @param  amount       Amount of WETH to deposit.
     * @param  minSharesOut Minimum weETH shares to receive.
     * @return shares       Actual weETH shares received.
     */
    function deposit(uint256 amount, uint256 minSharesOut) external returns (uint256 shares);

    /**
     * @notice Requests an ETH withdrawal by unwrapping weETH to eETH, then submitting the eETH to
     *         the EtherFi liquidity pool for withdrawal.
     * @param  weethModule   Address of the weETH withdrawal module.
     * @param  weethShares   Amount of weETH shares to withdraw.
     * @param  minEETHShares Minimum eETH shares after unwrapping (slippage check).
     * @return requestId     ID of the created withdrawal request.
     */
    function requestWithdraw(address weethModule, uint256 weethShares, uint256 minEETHShares)
        external
        returns (uint256 requestId);

    /**
     * @notice Sets the deposit rate limit for a given eETH token.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     * @param  maxAmount     Maximum amount of the rate limit.
     * @param  slope         Slope of the rate limit.
     * @param  lastAmount    Last amount of the rate limit.
     * @param  lastUpdated   Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address eeth,
        address liquidityPool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the request withdraw rate limit for a given eETH token and weETH module.
     * @param  weethModule   Address of the weETH withdrawal module.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     * @param  maxAmount     Maximum amount of the rate limit.
     * @param  slope         Slope of the rate limit.
     * @param  lastAmount    Last amount of the rate limit.
     * @param  lastUpdated   Timestamp of the last update of the rate limit.
     */
    function setRequestWithdrawRateLimit(
        address weethModule,
        address eeth,
        address liquidityPool,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdrawal request operations.
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /// @notice Address of the weETH token contract (immutable).
    function weeth() external view returns (address);

    /// @notice Address of the WETH token contract (immutable).
    function weth() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the deposit rate limit for a given eETH token.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     * @return data          Rate limit data.
     */
    function getDepositRateLimit(address eeth, address liquidityPool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the request withdraw rate limit for a given eETH token and weETH module.
     * @param  weethModule   Address of the weETH withdrawal module.
     * @param  eeth          Address of the eETH token.
     * @param  liquidityPool Address of the liquidity pool.
     * @return data          Rate limit data.
     */
    function getRequestWithdrawRateLimit(address weethModule, address eeth, address liquidityPool)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
