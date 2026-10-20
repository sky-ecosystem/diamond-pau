// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IWEETHController {

    function weeth_VERSION() external pure returns (string memory);

    function weeth_deposit(uint256 amount, uint256 minSharesOut) external returns (uint256 shares);

    function weeth_requestWithdraw(address weethModule, uint256 weethShares, uint256 minEETHShares)
        external
        returns (uint256 requestId);

    function weeth_claimWithdrawal(address weethModule, uint256 requestId)
        external
        returns (uint256 ethReceived);

    function weeth_getDepositRateLimitKey(address eeth, address liquidityPool)
        external
        pure
        returns (bytes32 key);

    function weeth_getRequestWithdrawRateLimitKey(
        address weethModule,
        address eeth,
        address liquidityPool
    )
        external
        pure
        returns (bytes32 key);

    function weeth_getClaimWithdrawRateLimitKey(address weethModule)
        external
        pure
        returns (bytes32 key);

    function weeth_weeth() external view returns (address);

    function weeth_weth() external view returns (address);

}
