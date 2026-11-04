// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import {
    makeAddressAddressAddressAddressKey,
    makeAddressAddressAddressKey
} from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISwapAssetFacet } from "./ISwapAssetFacet.sol";

interface IControllerLike {

    function swapAsset_completeSwap(
        address assetOut,
        address assetIn,
        uint256 amountOut,
        address initiatorController,
        bytes32 paymentId
    )
        external;

    function swapAsset_settleSwap(bytes32 paymentId) external;

    function proxy() external view returns (address);

}

interface IERC20Like {

    function transferFrom(address from, address to, uint256 amount) external returns (bool success);

    function allowance(address owner, address spender) external view returns (uint256 allowance);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimals);

}

/**
 * @dev    Swaps are settled explicitly (A -> B -> A) instead of via passive balance checks:
 *
 *         A.initiateSwap
 *          ├─ record a pending settlement { paymentId, B.proxy, assetIn, amountIn } (transient)
 *          ├─ A.proxy approves B.proxy for exactly `amountOut`
 *          └─ A.proxy → B.controller.completeSwap(..., A.controller, paymentId)
 *               ├─ B.proxy pulls `amountOut` from A.proxy
 *               ├─ B.proxy approves A.proxy for exactly `amountIn`
 *               ├─ B.proxy → A.controller.settleSwap(paymentId)
 *               │    └─ A.proxy pulls `amountIn` from B.proxy, marks the payment settled
 *               └─ B requires its allowance to A.proxy was fully consumed
 *          ├─ A requires the payment was settled
 *          └─ A requires its allowance to B.proxy was fully consumed
 *
 *         Each side receives its asset via an explicit `transferFrom` out of the other side's
 *         proxy, so an unrelated balance increase (e.g. a reentrant vault withdrawal or a nested
 *         swap) can no longer satisfy the settlement.
 */
contract SwapAssetFacet is ISwapAssetFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_INITIATE_ASSET_SWAP = keccak256("LIMIT_INITIATE_ASSET_SWAP");
    bytes32 internal constant _LIMIT_COMPLETE_ASSET_SWAP = keccak256("LIMIT_COMPLETE_ASSET_SWAP");

    // keccak256(abi.encode(uint256(keccak256("sky.pau.transient.SwapAsset")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant _PENDING_SETTLEMENT_LOCATION =
        0x9e85a6ba4d2a01fbc46ba79ec105f07461974042b4f46714cc5c4ff7ad444f00;

    uint256 internal constant _PAYMENT_ID_OFFSET         = 0;
    uint256 internal constant _COUNTERPARTY_PROXY_OFFSET = 1;
    uint256 internal constant _ASSET_IN_OFFSET           = 2;
    uint256 internal constant _AMOUNT_IN_OFFSET          = 3;
    uint256 internal constant _SETTLED_OFFSET            = 4;
    uint256 internal constant _NONCE_OFFSET              = 5;

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapAssetFacet
    function initiateSwap(
        address counterpartyController,
        address assetOut,
        address assetIn,
        uint256 amountOut
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        require(assetOut != assetIn, "SwapAssetFacet/same-asset");

        address counterpartyProxy = IControllerLike(counterpartyController).proxy();

        require(
            IALMProxy(counterpartyProxy).hasRole(
                IALMProxy(counterpartyProxy).CONTROLLER(),
                counterpartyController
            ),
            "SwapAssetFacet/invalid-counterparty-controller"
        );

        _decreaseRateLimit(
            getInitiateSwapRateLimitKey(
                assetOut,
                counterpartyProxy,
                counterpartyController,
                assetIn
            ),
            amountOut
        );

        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        _tryIncreaseRateLimit(
            getInitiateSwapRateLimitKey(
                assetIn,
                counterpartyProxy,
                counterpartyController,
                assetOut
            ),
            amountIn
        );

        address proxy = _getSharedControllerStorage().proxy;

        bytes32 paymentId = _openSettlement(counterpartyProxy, assetOut, assetIn, amountOut, amountIn);

        ApproveLib.approve(assetOut, proxy, counterpartyProxy, amountOut);

        IALMProxy(proxy).doCall(
            counterpartyController,
            abi.encodeCall(
                IControllerLike.swapAsset_completeSwap,
                (assetIn, assetOut, amountIn, address(this), paymentId)
            )
        );

        require(_tload(_SETTLED_OFFSET) == 1, "SwapAssetFacet/not-settled");

        // The counterparty must have pulled exactly `amountOut` (it cannot pull more than approved).
        require(
            IERC20Like(assetOut).allowance(proxy, counterpartyProxy) == 0,
            "SwapAssetFacet/amountOut-mismatch"
        );

        _closeSettlement();

        emit SwapAssetSwap(counterpartyProxy, assetOut, assetIn, amountOut, amountIn);
    }

    /// @inheritdoc ISwapAssetFacet
    function completeSwap(
        address assetOut,
        address assetIn,
        uint256 amountOut,
        address initiatorController,
        bytes32 paymentId
    )
        external
        override
        nonReentrant
    {
        address counterpartyProxy = msg.sender;

        // Does not have a hasRole check on msg.sender, but is permissioned through rate limit key
        // derivation as msg.sender has to be the counterparty proxy.
        _decreaseRateLimit(
            getCompleteSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            amountOut
        );

        // The callback target must be a Controller of the (rate-limit-whitelisted) counterparty.
        require(
            IALMProxy(counterpartyProxy).hasRole(
                IALMProxy(counterpartyProxy).CONTROLLER(),
                initiatorController
            ),
            "SwapAssetFacet/invalid-initiator-controller"
        );

        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        _tryIncreaseRateLimit(
            getCompleteSwapRateLimitKey(assetIn, counterpartyProxy, assetOut),
            amountIn
        );

        address proxy = _getSharedControllerStorage().proxy;

        // Get paid first, explicitly out of the counterparty proxy.
        _transferFrom(assetIn, counterpartyProxy, amountIn);

        // Let the initiator pull `amountOut` out of this proxy, bracketed by the callback.
        ApproveLib.approve(assetOut, proxy, counterpartyProxy, amountOut);

        IALMProxy(proxy).doCall(
            initiatorController,
            abi.encodeCall(IControllerLike.swapAsset_settleSwap, (paymentId))
        );

        require(
            IERC20Like(assetOut).allowance(proxy, counterpartyProxy) == 0,
            "SwapAssetFacet/not-pulled"
        );

        emit SwapAssetSwap(counterpartyProxy, assetOut, assetIn, amountOut, amountIn);
    }

    /// @inheritdoc ISwapAssetFacet
    function settleSwap(bytes32 paymentId) external override {
        // NOTE: Intentionally not `nonReentrant`, as `initiateSwap` holds the guard while this
        //       callback executes. It is gated by the transient pending settlement instead, which
        //       only exists while `initiateSwap` is executing on this Controller.
        require(
            paymentId != bytes32(0) && paymentId == bytes32(_tload(_PAYMENT_ID_OFFSET)),
            "SwapAssetFacet/invalid-payment-id"
        );

        address counterpartyProxy = address(uint160(_tload(_COUNTERPARTY_PROXY_OFFSET)));

        require(msg.sender == counterpartyProxy,  "SwapAssetFacet/invalid-settler");
        require(_tload(_SETTLED_OFFSET) == 0,     "SwapAssetFacet/already-settled");

        _tstore(_SETTLED_OFFSET, 1);

        address assetIn  = address(uint160(_tload(_ASSET_IN_OFFSET)));
        uint256 amountIn = _tload(_AMOUNT_IN_OFFSET);
        address proxy    = _getSharedControllerStorage().proxy;

        uint256 startingBalance = IERC20Like(assetIn).balanceOf(proxy);

        _transferFrom(assetIn, counterpartyProxy, amountIn);

        require(
            IERC20Like(assetIn).balanceOf(proxy) - startingBalance == amountIn,
            "SwapAssetFacet/amountIn-mismatch"
        );
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapAssetFacet
    function getInitiateSwapRateLimitKey(
        address assetOut,
        address counterpartyProxy,
        address counterpartyController,
        address assetIn
    )
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressAddressAddressKey(
            _LIMIT_INITIATE_ASSET_SWAP,
            assetOut,
            counterpartyProxy,
            counterpartyController,
            assetIn
        );
    }

    /// @inheritdoc ISwapAssetFacet
    function getCompleteSwapRateLimitKey(
        address assetOut,
        address counterpartyProxy,
        address assetIn
    )
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressAddressKey(
            _LIMIT_COMPLETE_ASSET_SWAP,
            assetOut,
            counterpartyProxy,
            assetIn
        );
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _openSettlement(
        address counterpartyProxy,
        address assetOut,
        address assetIn,
        uint256 amountOut,
        uint256 amountIn
    )
        internal
        returns (bytes32 paymentId)
    {
        uint256 nonce = _tload(_NONCE_OFFSET);

        _tstore(_NONCE_OFFSET, nonce + 1);

        paymentId = keccak256(
            abi.encode(
                block.chainid,
                address(this),
                counterpartyProxy,
                assetOut,
                assetIn,
                amountOut,
                nonce
            )
        );

        _tstore(_PAYMENT_ID_OFFSET,         uint256(paymentId));
        _tstore(_COUNTERPARTY_PROXY_OFFSET, uint256(uint160(counterpartyProxy)));
        _tstore(_ASSET_IN_OFFSET,           uint256(uint160(assetIn)));
        _tstore(_AMOUNT_IN_OFFSET,          amountIn);
        _tstore(_SETTLED_OFFSET,            0);
    }

    function _closeSettlement() internal {
        _tstore(_PAYMENT_ID_OFFSET,         0);
        _tstore(_COUNTERPARTY_PROXY_OFFSET, 0);
        _tstore(_ASSET_IN_OFFSET,           0);
        _tstore(_AMOUNT_IN_OFFSET,          0);
        _tstore(_SETTLED_OFFSET,            0);
    }

    function _transferFrom(address assetIn, address counterpartyProxy, uint256 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;

        bytes memory returnData = IALMProxy(proxy).doCall(
            assetIn,
            abi.encodeCall(IERC20Like.transferFrom, (counterpartyProxy, proxy, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "SwapAssetFacet/transfer-from-failed"
        );
    }

    function _tstore(uint256 offset, uint256 value) internal {
        bytes32 slot = bytes32(uint256(_PENDING_SETTLEMENT_LOCATION) + offset);

        assembly {
            tstore(slot, value)
        }
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _tload(uint256 offset) internal view returns (uint256 value) {
        bytes32 slot = bytes32(uint256(_PENDING_SETTLEMENT_LOCATION) + offset);

        assembly {
            value := tload(slot)
        }
    }

    // Converts an amount of assetFrom to the equivalent 1:1 amount of assetTo, reverting if the
    // precision would be lost.
    function _convertAmount(address assetFrom, address assetTo, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 decimalsFrom = IERC20Like(assetFrom).decimals();
        uint256 decimalsTo   = IERC20Like(assetTo).decimals();

        if (decimalsFrom <= decimalsTo) return amount * 10 ** (decimalsTo - decimalsFrom);

        uint256 scale = 10 ** (decimalsFrom - decimalsTo);

        require(amount % scale == 0, "SwapAssetFacet/precision-loss");

        return amount / scale;
    }

}
