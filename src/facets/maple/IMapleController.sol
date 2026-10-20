// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface IMapleController {

    function maple_VERSION() external pure returns (string memory);

    function maple_requestRedemption(address mapleToken, uint256 shares) external;

    function maple_cancelRedemption(address mapleToken, uint256 shares) external;

    function maple_getCancelRedeemRateLimitKey(address mapleToken)
        external
        pure
        returns (bytes32 key);

    function maple_getRequestRedeemRateLimitKey(address mapleToken)
        external
        pure
        returns (bytes32 key);

}
