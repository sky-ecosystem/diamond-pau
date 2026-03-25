// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IALMProxy }        from "../interfaces/IALMProxy.sol";
import { ICentrifugeFacet } from "../interfaces/facets/ICentrifugeFacet.sol";
import { IParameters }      from "../interfaces/IParameters.sol";
import { IRateLimits }      from "../interfaces/IRateLimits.sol";

import { combineKeyComponents, uint256ToKeyComponent } from "../ParameterKeys.sol";
import { makeAddressKey, makeAddressUint16Key }        from "../RateLimitHelpers.sol";

import { FacetBase } from "./FacetBase.sol";

interface IAsyncRedeemManagerLike {

    function spoke() external view returns (address);

}

interface ICentrifugeV3VaultLike {

    function cancelDepositRequest(uint256 requestId, address controller) external;

    function cancelRedeemRequest(uint256 requestId, address controller) external;

    function claimCancelDepositRequest(uint256 requestId, address receiver, address controller)
        external
        returns (uint256 assets);

    function claimCancelRedeemRequest(uint256 requestId, address receiver, address controller)
        external
        returns (uint256 shares);

    function baseManager() external view returns (address);

    function poolId() external view returns (uint64);

    function scId() external view returns (bytes16);

}

interface ISpokeLike {

    function crosschainTransferShares(
        uint16  centrifugeId,
        uint64  poolId,
        bytes16 scId,
        bytes32 receiver,
        uint128 amount,
        uint128 remoteExtraGasLimit
    ) external payable;

}

contract CentrifugeFacet is ICentrifugeFacet, FacetBase {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    string public constant CENTRIFUGE_RECIPIENT_PREFIX = "sky.pau.centrifuge.recipient";

    bytes32 public constant LIMIT_TRANSFER = keccak256("LIMIT_CENTRIFUGE_TRANSFER");
    bytes32 public constant LIMIT_DEPOSIT  = keccak256("LIMIT_7540_DEPOSIT");
    bytes32 public constant LIMIT_REDEEM   = keccak256("LIMIT_7540_REDEEM");

    // Requests for Centrifuge pools are non-fungible and all have ID = 0.
    uint256 public constant REQUEST_ID = 0;

    /**********************************************************************************************/
    /*** External interactive functions                                                         ***/
    /**********************************************************************************************/

    function setCentrifugeRecipient(uint16 centrifugeId, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IParameters(_getControllerStorage().parameters).set(
            _getCentrifugeRecipientKey(centrifugeId),
            recipient
        );

        emit CentrifugeRecipientSet(centrifugeId, recipient);
    }

    function cancelDepositRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _rateLimitExists($.rateLimits, makeAddressKey(LIMIT_DEPOSIT, token));

        // NOTE: While the cancellation is pending, no new deposit request can be submitted.
        IALMProxy($.proxy).doCall(
            token,
            abi.encodeCall(ICentrifugeV3VaultLike(token).cancelDepositRequest, (REQUEST_ID, $.proxy))
        );
    }

    function claimCancelDepositRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _rateLimitExists($.rateLimits, makeAddressKey(LIMIT_DEPOSIT, token));

        IALMProxy($.proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).claimCancelDepositRequest,
                (REQUEST_ID, $.proxy, $.proxy)
            )
        );
    }

    function cancelRedeemRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _rateLimitExists($.rateLimits, makeAddressKey(LIMIT_REDEEM, token));

        // NOTE: While the cancellation is pending, no new redeem request can be submitted.
        IALMProxy($.proxy).doCall(
            token,
            abi.encodeCall(ICentrifugeV3VaultLike(token).cancelRedeemRequest, (REQUEST_ID, $.proxy))
        );
    }

    function claimCancelRedeemRequest(address token)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        _rateLimitExists($.rateLimits, makeAddressKey(LIMIT_REDEEM, token));

        IALMProxy($.proxy).doCall(
            token,
            abi.encodeCall(
                ICentrifugeV3VaultLike(token).claimCancelRedeemRequest,
                (REQUEST_ID, $.proxy, $.proxy)
            )
        );
    }

    function transferShares(address token, uint128 amount, uint16 centrifugeId)
        external
        payable
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        ControllerStorage storage $ = _getControllerStorage();

        IRateLimits($.rateLimits).triggerRateLimitDecrease(
            makeAddressUint16Key(LIMIT_TRANSFER, token, centrifugeId),
            amount
        );

        bytes32 recipient = IParameters($.parameters).get(_getCentrifugeRecipientKey(centrifugeId));

        require(recipient != 0, "CentrifugeFacet/id-not-configured");

        address spoke = IAsyncRedeemManagerLike(ICentrifugeV3VaultLike(token).baseManager()).spoke();

        // Initiate cross-chain transfer via the specific spoke address
        IALMProxy($.proxy).doCallWithValue{value: msg.value}(
            spoke,
            abi.encodeCall(
                ISpokeLike.crosschainTransferShares,
                (
                    centrifugeId,
                    ICentrifugeV3VaultLike(token).poolId(),
                    ICentrifugeV3VaultLike(token).scId(),
                    recipient,
                    amount,
                    0
                )
            ),
            msg.value
        );
    }

    /**********************************************************************************************/
    /*** External view/pure functions                                                           ***/
    /**********************************************************************************************/

    function centrifugeRecipients(uint16 centrifugeId) external view returns (bytes32) {
        return IParameters(_getControllerStorage().parameters).get(
            _getCentrifugeRecipientKey(centrifugeId)
        );
    }

    /**********************************************************************************************/
    /*** Internal view/pure functions                                                           ***/
    /**********************************************************************************************/

    function _rateLimitExists(address rateLimits, bytes32 key) internal view {
        require(
            IRateLimits(rateLimits).getRateLimitData(key).maxAmount > 0,
            "CentrifugeFacet/invalid-action"
        );
    }

    function _getCentrifugeRecipientKey(uint16 centrifugeId)
        internal
        pure
        returns (string memory)
    {
        return combineKeyComponents(
            CENTRIFUGE_RECIPIENT_PREFIX,
            uint256ToKeyComponent(uint256(centrifugeId))
        );
    }

}
