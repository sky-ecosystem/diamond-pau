// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IWSTETHController {

    function wsteth_VERSION() external pure returns (string memory);

    function wsteth_deposit(uint256 amount) external;

    function wsteth_requestWithdraw(uint256 amountToRedeem)
        external
        returns (uint256[] memory requestIds);

    function wsteth_claimWithdrawal(uint256 requestId) external;

    function wsteth_depositRateLimitKey() external pure returns (bytes32 key);

    function wsteth_requestWithdrawRateLimitKey() external pure returns (bytes32 key);

    function wsteth_claimWithdrawRateLimitKey() external pure returns (bytes32 key);

    function wsteth_weth() external view returns (address);

    function wsteth_withdrawQueue() external view returns (address);

    function wsteth_wsteth() external view returns (address);

}
