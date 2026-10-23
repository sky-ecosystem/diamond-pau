// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import { makeAddressAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISwapAssetFacet } from "./ISwapAssetFacet.sol";

interface IControllerLike {

    function swapAsset_completeSwap(address assetOut, address assetIn, uint256 amount) external;

    function proxy() external view returns (address);

}

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool success);

    function transferFrom(address from, address to, uint256 amount) external returns (bool success);

    function approve(address to, uint256 amount) external returns (bool success);

    function balanceOf(address owner) external view returns (uint256 balance);

}

contract SwapAssetFacet is ISwapAssetFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_SWAP = keccak256("LIMIT_ASSET_SWAP");

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
        uint256 amount
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        address counterpartyProxy = IControllerLike(counterpartyController).proxy();

        _decreaseRateLimit(getSwapRateLimitKey(assetOut, counterpartyProxy, assetIn), amount);

        address proxy = _getSharedControllerStorage().proxy;

        ApproveLib.approve(assetOut, proxy, counterpartyProxy, amount);

        uint256 startingAssetsOutBalance = IERC20Like(assetOut).balanceOf(proxy);
        uint256 startingAssetsInBalance  = IERC20Like(assetIn).balanceOf(proxy);

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            counterpartyController,
            abi.encodeCall(IControllerLike.swapAsset_completeSwap, (assetIn, assetOut, amount))
        );

        uint256 amountOut = startingAssetsOutBalance - IERC20Like(assetOut).balanceOf(proxy);
        uint256 amountIn  = IERC20Like(assetIn).balanceOf(proxy) - startingAssetsInBalance;

        ApproveLib.approve(assetOut, proxy, counterpartyProxy, 0);

        require(amountOut == amount, "SwapAssetFacet/amountOut-mismatch");
        require(amountIn == amount,  "SwapAssetFacet/amountIn-mismatch");

        emit SwapAssetSwapInitiated(counterpartyProxy, assetOut, assetIn, amount);
    }

    function completeSwap(address assetOut, address assetIn, uint256 amount)
        external
        override
        nonReentrant
    {
        address counterpartyProxy = msg.sender;

        _decreaseRateLimit(getSwapRateLimitKey(assetOut, counterpartyProxy, assetIn), amount);

        _transferFrom(assetIn, counterpartyProxy, amount);
        _transfer(assetOut, counterpartyProxy, amount);

        emit SwapAssetSwapCompleted(counterpartyProxy, assetOut, assetIn, amount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapAssetFacet
    function getSwapRateLimitKey(address assetOut, address counterpartyProxy, address assetIn)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressAddressKey(_LIMIT_SWAP, assetOut, counterpartyProxy, assetIn);
    }

    /**********************************************************************************************/
    /*** Internal Internal Functions                                                            ***/
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

}
