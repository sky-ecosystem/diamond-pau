// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Ethereum } from "../../lib/spark-address-registry/src/Ethereum.sol";

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

interface IERC20ike {

    function approve(address spender, uint256 amount) external returns (bool success);

}

interface IWETHLike {

    function withdraw(uint256 amount) external;

}

interface IWithdrawalQueueLike {

    function requestWithdrawalsWstETH(uint256[] calldata amounts, address owner)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawal(uint256 requestId) external;

}

interface IWSTETHLike {

    function getStETHByWstETH(uint256 wstETHAmount) external view returns (uint256);

}

library WSTETHLib {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant LIMIT_DEPOSIT          = keccak256("LIMIT_WSTETH_DEPOSIT");
    bytes32 public constant LIMIT_REQUEST_WITHDRAW = keccak256("LIMIT_WSTETH_REQUEST_WITHDRAW");

    /**********************************************************************************************/
    /*** External interactive functions                                                         ***/
    /**********************************************************************************************/

    function deposit(address proxy, address rateLimits, uint256 amount) external {
        _decreaseRateLimit(rateLimits, LIMIT_DEPOSIT, amount);

        IALMProxy(proxy).doCall(Ethereum.WETH, abi.encodeCall(IWETHLike.withdraw, (amount)));

        IALMProxy(proxy).doCallWithValue(Ethereum.WSTETH, "", amount);
    }

    function requestWithdraw(address proxy, address rateLimits, uint256 amountToRedeem)
        external
        returns (uint256[] memory requestIds)
    {
        uint256 stethAmount = IWSTETHLike(Ethereum.WSTETH).getStETHByWstETH(amountToRedeem);

        _decreaseRateLimit(rateLimits, LIMIT_REQUEST_WITHDRAW, stethAmount);

        IALMProxy(proxy).doCall(
            Ethereum.WSTETH,
            abi.encodeCall(IERC20ike.approve, (Ethereum.WSTETH_WITHDRAW_QUEUE, amountToRedeem))
        );

        uint256[] memory amountsToRedeem = new uint256[](1);
        amountsToRedeem[0] = amountToRedeem;

        return abi.decode(
            IALMProxy(proxy).doCall(
                Ethereum.WSTETH_WITHDRAW_QUEUE,
                abi.encodeCall(
                    IWithdrawalQueueLike.requestWithdrawalsWstETH,
                    (amountsToRedeem, proxy)
                )
            ),
            (uint256[])
        );
    }

    function claimWithdrawal(address proxy, address rateLimits, uint256 requestId) external {
        require(
            IRateLimits(rateLimits).getRateLimitData(LIMIT_REQUEST_WITHDRAW).maxAmount > 0,
            "WSTETHLib/invalid-action"
        );

        uint256 initialETHBalance = proxy.balance;

        IALMProxy(proxy).doCall(
            Ethereum.WSTETH_WITHDRAW_QUEUE,
            abi.encodeCall(IWithdrawalQueueLike.claimWithdrawal, (requestId))
        );

        IALMProxy(proxy).doCallWithValue(Ethereum.WETH, "", proxy.balance - initialETHBalance);
    }

    /**********************************************************************************************/
    /*** Internal interactive functions                                                         ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(address rateLimits, bytes32 key, uint256 amount) internal {
        IRateLimits(rateLimits).triggerRateLimitDecrease(key, amount);
    }

}
