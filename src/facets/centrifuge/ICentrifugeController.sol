// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

interface ICentrifugeController {

    function centrifuge_VERSION() external pure returns (string memory);

    function centrifuge_REQUEST_ID() external pure returns (uint256);

    function centrifuge_setRecipient(uint16 centrifugeId, bytes32 recipient) external;

    function centrifuge_cancelDepositRequest(address token) external;

    function centrifuge_claimCancelDepositRequest(address token) external;

    function centrifuge_cancelRedeemRequest(address token) external;

    function centrifuge_claimCancelRedeemRequest(address token) external;

    function centrifuge_transferShares(address token, uint128 amount, uint16 centrifugeId)
        external
        payable;

    function centrifuge_getRecipient(uint16 centrifugeId) external view returns (bytes32);

    function centrifuge_getCancelDepositRateLimitKey(address token)
        external
        pure
        returns (bytes32 key);

    function centrifuge_getClaimCancelDepositRateLimitKey(address token)
        external
        pure
        returns (bytes32 key);

    function centrifuge_getCancelRedeemRateLimitKey(address token)
        external
        pure
        returns (bytes32 key);

    function centrifuge_getClaimCancelRedeemRateLimitKey(address token)
        external
        pure
        returns (bytes32 key);

    function centrifuge_getTransferRateLimitKey(address token, uint16 centrifugeId, address spoke)
        external
        pure
        returns (bytes32 key);

}
