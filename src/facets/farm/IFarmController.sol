// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IFarmController {

    function farm_VERSION() external pure returns (string memory);

    function farm_deposit(address farm, uint256 amount) external;

    function farm_claimReward(address farm) external returns (uint256 reward);

    function farm_withdraw(address farm, uint256 amount) external;

    function farm_getClaimRewardRateLimitKey(address farm) external pure returns (bytes32 key);

    function farm_getDepositRateLimitKey(address farm, address stakingToken)
        external
        pure
        returns (bytes32 key);

    function farm_getWithdrawRateLimitKey(address farm) external pure returns (bytes32 key);

}
