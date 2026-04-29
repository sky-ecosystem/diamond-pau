// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { makeAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ITransferAssetFacet } from "./ITransferAssetFacet.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool success);

}

contract TransferAssetFacet is ITransferAssetFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc ITransferAssetFacet
    bytes32 public constant override LIMIT_TRANSFER = keccak256("LIMIT_ASSET_TRANSFER");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ITransferAssetFacet
    function setTransferRateLimit(
        address asset,
        address destination,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(asset != address(0),       "TransferAssetFacet/asset-zero-address");
        require(destination != address(0), "TransferAssetFacet/destination-zero-address");

        bytes32 key = _getTransferRateLimitKey(asset, destination);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit TransferAssetRateLimitSet(key, asset, destination);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc ITransferAssetFacet
    function transfer(address asset, address destination, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _decreaseRateLimit(_getTransferRateLimitKey(asset, destination), amount);

        bytes memory returnData = IALMProxy(_getSharedControllerStorage().proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transfer, (destination, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "TransferAssetFacet/transfer-failed"
        );

        emit TransferAssetTransfer(asset, destination, amount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ITransferAssetFacet
    function getTransferRateLimit(address asset, address destination)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getTransferRateLimitKey(asset, destination));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getTransferRateLimitKey(address asset, address destination)
        internal
        pure
        returns (bytes32)
    {
        return makeAddressAddressKey(LIMIT_TRANSFER, asset, destination);
    }

}
