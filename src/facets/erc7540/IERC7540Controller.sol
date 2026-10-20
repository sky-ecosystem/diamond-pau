// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IERC7540Controller {

    function erc7540_VERSION() external pure returns (string memory);

    function erc7540_requestDeposit(address token, uint256 amount) external;

    function erc7540_claimDeposit(address token) external;

    function erc7540_requestRedeem(address token, uint256 shares) external;

    function erc7540_claimRedeem(address token) external;

    function erc7540_getRequestDepositRateLimitKey(address token, address asset)
        external
        pure
        returns (bytes32 key);

    function erc7540_getClaimDepositRateLimitKey(address token) external pure returns (bytes32 key);

    function erc7540_getRequestRedeemRateLimitKey(address token)
        external
        pure
        returns (bytes32 key);

    function erc7540_getClaimRedeemRateLimitKey(address token) external pure returns (bytes32 key);

}
