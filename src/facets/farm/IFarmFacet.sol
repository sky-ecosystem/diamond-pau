// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IFarmFacet
 * @notice PAU facet for staking tokens into and withdrawing from staking reward farms. Withdrawal
 *         also claims pending rewards.
 */
interface IFarmFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when staking tokens are deposited into a farm.
     * @param  farm   Address of the farm contract.
     * @param  amount Amount of staking tokens deposited.
     */
    event FarmDeposit(address indexed farm, uint256 amount);

    /**
     * @notice Emitted when the farm deposit rate limit is updated.
     * @param  key          Derived key of the rate limit.
     * @param  farm         Address of the farm contract.
     * @param  stakingToken Address of the staking token for the farm.
     */
    event FarmDepositRateLimitSet(bytes32 indexed key, address indexed farm, address stakingToken);

    /**
     * @notice Emitted when rewards are claimed from a farm without unstaking.
     * @param  farm Address of the farm contract.
     */
    event FarmReward(address indexed farm, uint256 amount);

    /**
     * @notice Emitted when staking tokens are withdrawn from a farm.
     * @param  farm   Address of the farm contract.
     * @param  amount Amount of staking tokens withdrawn.
     */
    event FarmWithdraw(address indexed farm, uint256 amount);

    /**
     * @notice Emitted when the farm withdraw rate limit is updated.
     * @param  key  Derived key of the rate limit.
     * @param  farm Address of the farm contract.
     */
    event FarmWithdrawRateLimitSet(bytes32 indexed key, address indexed farm);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Claims pending rewards from a farm without unstaking.
     * @param  farm   Address of the farm contract.
     * @return reward Amount of rewards claimed.
     */
    function claimReward(address farm) external returns (uint256 reward);

    /**
     * @notice Stakes tokens into a farm contract.
     * @param  farm   Address of the farm contract.
     * @param  amount Amount of staking tokens to deposit.
     */
    function deposit(address farm, uint256 amount) external;

    /**
     * @notice Sets the deposit rate limit for a farm.
     * @param  farm         Address of the farm contract.
     * @param  stakingToken Address of the staking token for the farm.
     * @param  maxAmount    Maximum amount of the rate limit.
     * @param  slope        Slope of the rate limit.
     * @param  lastAmount   Last amount of the rate limit.
     * @param  lastUpdated  Timestamp of the last update of the rate limit.
     */
    function setDepositRateLimit(
        address farm,
        address stakingToken,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Sets the withdraw rate limit for a farm.
     * @param  farm        Address of the farm contract.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setWithdrawRateLimit(
        address farm,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Unstakes tokens from a farm and claims pending rewards.
     * @param  farm   Address of the farm contract.
     * @param  amount Amount of staking tokens to withdraw.
     * @return reward Amount of rewards claimed.
     */
    function withdraw(address farm, uint256 amount) external returns (uint256 reward);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for withdraw operations.
    function LIMIT_WITHDRAW() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured deposit rate limit for a farm.
     * @param  farm         Address of the farm contract.
     * @param  stakingToken Address of the staking token for the farm.
     * @return data         Rate limit data.
     */
    function getDepositRateLimit(address farm, address stakingToken)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

    /**
     * @notice Returns the configured withdraw rate limit for a farm.
     * @param  farm Address of the farm contract.
     * @return data Rate limit data.
     */
    function getWithdrawRateLimit(address farm)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
