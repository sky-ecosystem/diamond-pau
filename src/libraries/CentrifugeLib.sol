// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import {
    ICentrifugeV3VaultLike,
    IAsyncRedeemManagerLike,
    ISpokeLike
} from "../interfaces/CentrifugeInterfaces.sol";

import { RateLimitHelpers } from "../RateLimitHelpers.sol";

library CentrifugeLib {

    bytes32 public constant LIMIT_CENTRIFUGE_TRANSFER = keccak256("LIMIT_CENTRIFUGE_TRANSFER");
    bytes32 public constant LIMIT_7540_DEPOSIT        = keccak256("LIMIT_7540_DEPOSIT");
    bytes32 public constant LIMIT_7540_REDEEM         = keccak256("LIMIT_7540_REDEEM");

    function cancelCentrifugeDepositRequest(
        address proxy,
        address rateLimits,
        address token,
        uint256 requestId
    )
        external
    {
        _rateLimitExists(IRateLimits(rateLimits), RateLimitHelpers.makeAddressKey(LIMIT_7540_DEPOSIT, token));

        // NOTE: While the cancelation is pending, no new deposit request can be submitted
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).cancelDepositRequest,
                (requestId, proxy)
            )
        );
    }

    function claimCentrifugeCancelDepositRequest(
        address proxy,
        address rateLimits,
        address token,
        uint256 requestId
    ) external {
        _rateLimitExists(IRateLimits(rateLimits), RateLimitHelpers.makeAddressKey(LIMIT_7540_DEPOSIT, token));

        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).claimCancelDepositRequest,
                (requestId, proxy, proxy)
            )
        );
    }

    function cancelCentrifugeRedeemRequest(
        address proxy,
        address rateLimits,
        address token,
        uint256 requestId
    ) external {
        _rateLimitExists(IRateLimits(rateLimits), RateLimitHelpers.makeAddressKey(LIMIT_7540_REDEEM, token));

        // NOTE: While the cancelation is pending, no new redeem request can be submitted
        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).cancelRedeemRequest,
                (requestId, proxy)
            )
        );
    }

    function claimCentrifugeCancelRedeemRequest(
        address proxy,
        address rateLimits,
        address token,
        uint256 requestId
    ) external {
        _rateLimitExists(IRateLimits(rateLimits), RateLimitHelpers.makeAddressKey(LIMIT_7540_REDEEM, token));

        IALMProxy(proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).claimCancelRedeemRequest,
                (requestId, proxy, proxy)
            )
        );
    }

    function transferSharesCentrifuge(
        address proxy,
        address rateLimits,
        address token,
        uint16  destinationCentrifugeId,
        uint128 amount,
        bytes32 recipient
    ) external {
        _rateLimited(
            IRateLimits(rateLimits),
            keccak256(abi.encode(LIMIT_CENTRIFUGE_TRANSFER, token, destinationCentrifugeId)),
            amount
        );

        require(recipient != 0, "CentrifugeLib/id-not-configured");

        ICentrifugeV3VaultLike centrifugeVault = ICentrifugeV3VaultLike(token);

        address spoke = IAsyncRedeemManagerLike(centrifugeVault.manager()).spoke();

        // Initiate cross-chain transfer via the specific spoke address
        IALMProxy(proxy).doCallWithValue{value: msg.value}(
            spoke,
            abi.encodeCall(
                ISpokeLike(spoke).crosschainTransferShares,
                (
                    destinationCentrifugeId,
                    centrifugeVault.poolId(),
                    centrifugeVault.scId(),
                    recipient,
                    amount,
                    0
                )
            ),
            msg.value
        );
    }

    /**********************************************************************************************/
    /*** Rate Limit helper functions                                                            ***/
    /**********************************************************************************************/

    function _rateLimited(IRateLimits rateLimits, bytes32 key, uint256 amount) internal {
        rateLimits.triggerRateLimitDecrease(key, amount);
    }

    function _rateLimitExists(IRateLimits rateLimits, bytes32 key) internal view {
        require(
            rateLimits.getRateLimitData(key).maxAmount > 0,
            "CentrifugeLib/invalid-action"
        );
    }

}
