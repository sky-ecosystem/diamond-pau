// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }                    from "../../libraries/ApproveLib.sol";
import { makeAddressAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISwapFacet } from "./ISwapFacet.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

contract SwapFacet is ISwapFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.SwapFacet.v1
    struct FacetStorage {
        mapping (address asset => AssetParameters parameters) assetParameters;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.SwapFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x0595ef9bfbf34d66b090a0bfaf6b93226b00b9342e3903cee8d1ec7852117800;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 internal constant _LIMIT_SWAP = keccak256("LIMIT_SWAP");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function approve(address asset, address counterparty, uint256 allowance)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(asset        != address(0), "SwapFacet/asset-zero-address");
        require(counterparty != address(0), "SwapFacet/counterparty-zero-address");

        address proxy = _getSharedControllerStorage().proxy;

        require(counterparty != proxy, "SwapFacet/counterparty-equals-proxy");

        // NOTE: Standing allowance. It is the only way a counterparty PAU can pull `asset` from
        //       this proxy, so it is also the hard bound on what that counterparty can take.
        ApproveLib.approve(asset, proxy, counterparty, allowance);

        emit SwapAllowanceSet(asset, counterparty, allowance);
    }

    /// @inheritdoc ISwapFacet
    function setParValue(address asset, uint256 parValue)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(asset != address(0), "SwapFacet/asset-zero-address");

        // NOTE: Decimals are snapshotted here so that `swap` makes no mutable external read
        //       when pricing. Tokens are assumed to have fixed decimals.
        uint8 decimals = IERC20Like(asset).decimals();

        _getFacetStorage().assetParameters[asset] = AssetParameters(parValue, decimals);

        emit SwapParValueSet(asset, parValue, decimals);
    }

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function swap(
        address counterparty,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
        returns (uint256 amountOut)
    {
        require(assetIn != assetOut, "SwapFacet/same-asset");
        require(amountIn != 0,       "SwapFacet/zero-amount-in");

        _decreaseRateLimit(getSwapRateLimitKey(assetIn, assetOut, counterparty), amountIn);

        amountOut = getAmountOut(assetIn, assetOut, amountIn);

        require(amountOut != 0,            "SwapFacet/zero-amount-out");
        require(amountOut >= minAmountOut, "SwapFacet/min-amount-out-not-met");

        address proxy = _getSharedControllerStorage().proxy;

        uint256 startingBalance = IERC20Like(assetOut).balanceOf(proxy);

        _transfer(proxy, assetIn, counterparty, amountIn);
        _transferFrom(proxy, assetOut, counterparty, amountOut);

        require(
            IERC20Like(assetOut).balanceOf(proxy) - startingBalance == amountOut,
            "SwapFacet/amount-out-mismatch"
        );

        _tryIncreaseRateLimit(getSwapRateLimitKey(assetOut, assetIn, counterparty), amountOut);

        emit SwapExecuted(counterparty, assetIn, assetOut, amountIn, amountOut);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function getAmountOut(address assetIn, address assetOut, uint256 amountIn)
        public
        view
        override
        returns (uint256 amountOut)
    {
        FacetStorage storage $ = _getFacetStorage();

        AssetParameters storage paramsIn  = $.assetParameters[assetIn];
        AssetParameters storage paramsOut = $.assetParameters[assetOut];

        uint256 parValueIn  = paramsIn.parValue;
        uint256 parValueOut = paramsOut.parValue;

        require(parValueIn  != 0, "SwapFacet/par-value-in-not-set");
        require(parValueOut != 0, "SwapFacet/par-value-out-not-set");

        // amountOut = amountIn * (parValueIn / 10^decimalsIn) / (parValueOut / 10^decimalsOut)
        return amountIn * parValueIn * 10 ** paramsOut.decimals
            / (parValueOut * 10 ** paramsIn.decimals);
    }

    /// @inheritdoc ISwapFacet
    function getAssetParameters(address asset)
        external
        view
        override
        returns (uint256 parValue, uint8 decimals)
    {
        AssetParameters storage params = _getFacetStorage().assetParameters[asset];

        return (params.parValue, params.decimals);
    }

    /// @inheritdoc ISwapFacet
    function getSwapRateLimitKey(address assetIn, address assetOut, address counterparty)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressAddressKey(_LIMIT_SWAP, assetIn, assetOut, counterparty);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _transfer(address proxy, address asset, address destination, uint256 amount)
        internal
    {
        bytes memory returnData = IALMProxy(proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transfer, (destination, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "SwapFacet/transfer-failed"
        );
    }

    function _transferFrom(address proxy, address asset, address source, uint256 amount)
        internal
    {
        bytes memory returnData = IALMProxy(proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transferFrom, (source, proxy, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "SwapFacet/transferFrom-failed"
        );
    }

}
