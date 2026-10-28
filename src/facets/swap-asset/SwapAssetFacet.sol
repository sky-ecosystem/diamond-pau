// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import { makeAddressAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISwapAssetFacet } from "./ISwapAssetFacet.sol";

interface IControllerLike {

    function swapAsset_completeSwap(address assetOut, address assetIn, uint256 amountOut) external;

    function proxy() external view returns (address);

}

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool success);

    function transferFrom(address from, address to, uint256 amount) external returns (bool success);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimals);

}

contract SwapAssetFacet is ISwapAssetFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_INITIATE_ASSET_SWAP = keccak256("LIMIT_INITIATE_ASSET_SWAP");
    bytes32 internal constant _LIMIT_COMPLETE_ASSET_SWAP = keccak256("LIMIT_COMPLETE_ASSET_SWAP");

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
        address counterpartyProxy = IControllerLike(counterpartyController).proxy();

        require(
            IALMProxy(counterpartyProxy).hasRole(
                IALMProxy(counterpartyProxy).CONTROLLER(),
                counterpartyController
            ),
            "SwapAssetFacet/invalid-counterparty-controller"
        );

        _decreaseRateLimit(
            getInitiateSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            amountOut
        );

        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        _tryIncreaseRateLimit(
            getInitiateSwapRateLimitKey(assetIn, counterpartyProxy, assetOut),
            amountIn
        );

        address proxy = _getSharedControllerStorage().proxy;

        ApproveLib.approve(assetOut, proxy, counterpartyProxy, amountOut);

        uint256 startingAssetsOutBalance = IERC20Like(assetOut).balanceOf(proxy);
        uint256 startingAssetsInBalance  = IERC20Like(assetIn).balanceOf(proxy);

        IALMProxy(proxy).doCall(
            counterpartyController,
            abi.encodeCall(IControllerLike.swapAsset_completeSwap, (assetIn, assetOut, amountIn))
        );

        ApproveLib.approve(assetOut, proxy, counterpartyProxy, 0);

        uint256 amountOutSent    = startingAssetsOutBalance - IERC20Like(assetOut).balanceOf(proxy);
        uint256 amountInReceived = IERC20Like(assetIn).balanceOf(proxy) - startingAssetsInBalance;

        require(amountOutSent    == amountOut, "SwapAssetFacet/amountOut-mismatch");
        require(amountInReceived == amountIn,  "SwapAssetFacet/amountIn-mismatch");

        emit SwapAssetSwap(counterpartyProxy, assetOut, assetIn, amountOutSent, amountInReceived);
    }

    /// @inheritdoc ISwapAssetFacet
    function completeSwap(address assetOut, address assetIn, uint256 amountOut)
        external
        override
        nonReentrant
    {
        address counterpartyProxy = msg.sender;

        // Does not have a hasRole check, but is permissioned through rate limit key derivation
        // as msg.sender has to be the counterparty proxy.
        _decreaseRateLimit(
            getCompleteSwapRateLimitKey(assetOut, counterpartyProxy, assetIn),
            amountOut
        );

        uint256 amountIn = _convertAmount(assetOut, assetIn, amountOut);

        _tryIncreaseRateLimit(
            getCompleteSwapRateLimitKey(assetIn, counterpartyProxy, assetOut),
            amountIn
        );

        _transferFrom(assetIn, counterpartyProxy, amountIn);
        _transfer(assetOut,    counterpartyProxy, amountOut);

        emit SwapAssetSwap(counterpartyProxy, assetOut, assetIn, amountOut, amountIn);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapAssetFacet
    function getInitiateSwapRateLimitKey(
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
            _LIMIT_INITIATE_ASSET_SWAP,
            assetOut,
            counterpartyProxy,
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

    function _transfer(address assetOut, address counterpartyProxy, uint256 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;

        bytes memory returnData = IALMProxy(proxy).doCall(
            assetOut,
            abi.encodeCall(IERC20Like.transfer, (counterpartyProxy, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "SwapAssetFacet/transfer-failed"
        );
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

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

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
