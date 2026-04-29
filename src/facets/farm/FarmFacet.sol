// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }                            from "../../libraries/ApproveLib.sol";
import { makeAddressAddressKey, makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IFarmFacet } from "./IFarmFacet.sol";

interface IERC20Like {

    function balanceOf(address account) external view returns (uint256);

}

interface IFarmLike {

    function getReward() external;

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function rewardsToken() external view returns (address);

    function stakingToken() external view returns (address);

}

contract FarmFacet is IFarmFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IFarmFacet
    bytes32 public constant override LIMIT_DEPOSIT = keccak256("LIMIT_FARM_DEPOSIT");

    /// @inheritdoc IFarmFacet
    bytes32 public constant override LIMIT_WITHDRAW = keccak256("LIMIT_FARM_WITHDRAW");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IFarmFacet
    function setDepositRateLimit(
        address farm,
        address stakingToken,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(farm != address(0),         "FarmFacet/farm-zero-address");
        require(stakingToken != address(0), "FarmFacet/staking-token-zero-address");

        bytes32 key = _getDepositRateLimitKey(farm, stakingToken);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit FarmDepositRateLimitSet(key, farm, stakingToken);
    }

    /// @inheritdoc IFarmFacet
    function setWithdrawRateLimit(
        address farm,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(farm != address(0), "FarmFacet/farm-zero-address");

        bytes32 key = _getWithdrawRateLimitKey(farm);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit FarmWithdrawRateLimitSet(key, farm);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IFarmFacet
    function deposit(address farm, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        address proxy        = _getSharedControllerStorage().proxy;
        address stakingToken = IFarmLike(farm).stakingToken();

        _decreaseRateLimit(_getDepositRateLimitKey(farm, stakingToken), amount);

        ApproveLib.approve(stakingToken, proxy, farm, amount);

        IALMProxy(proxy).doCall(farm, abi.encodeCall(IFarmLike.stake, (amount)));

        emit FarmDeposit(farm, amount);
    }

    /// @inheritdoc IFarmFacet
    function claimReward(address farm)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 reward)
    {
        return _claimReward(farm);
    }

    /// @inheritdoc IFarmFacet
    function withdraw(address farm, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
        returns (uint256 reward)
    {
        _decreaseRateLimit(_getWithdrawRateLimitKey(farm), amount);

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            farm,
            abi.encodeCall(IFarmLike.withdraw, (amount))
        );

        emit FarmWithdraw(farm, amount);

        return _claimReward(farm);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IFarmFacet
    function getDepositRateLimit(address farm, address stakingToken)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getDepositRateLimitKey(farm, stakingToken));
    }

    /// @inheritdoc IFarmFacet
    function getWithdrawRateLimit(address farm)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getWithdrawRateLimitKey(farm));
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _claimReward(address farm) internal returns (uint256 reward) {
        address proxy        = _getSharedControllerStorage().proxy;
        address rewardsToken = IFarmLike(farm).rewardsToken();

        uint256 startingBalance = IERC20Like(rewardsToken).balanceOf(proxy);

        IALMProxy(proxy).doCall(farm, abi.encodeCall(IFarmLike.getReward, ()));

        reward = IERC20Like(rewardsToken).balanceOf(proxy) - startingBalance;

        emit FarmReward(farm, reward);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getDepositRateLimitKey(address farm, address stakingToken) internal pure returns (bytes32) {
        return makeAddressAddressKey(LIMIT_DEPOSIT, stakingToken, farm);
    }

    function _getWithdrawRateLimitKey(address farm) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_WITHDRAW, farm);
    }

}
