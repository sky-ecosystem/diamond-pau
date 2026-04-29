// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ITransferAssetFacet
 * @notice PAU facet for transferring ERC-20 assets from the proxy to a destination address. Rate
 *         limited per asset and destination pair.
 */
interface ITransferAssetFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an ERC-20 asset is transferred from the proxy.
     * @param  asset       Address of the transferred asset token.
     * @param  destination Address that received the asset.
     * @param  amount      Amount of asset transferred (native token decimals).
     */
    event TransferAssetTransfer(address indexed asset, address indexed destination, uint256 amount);

    /**
     * @notice Emitted when the transfer rate limit is updated.
     * @param  key         Derived key of the rate limit.
     * @param  asset       Address of the asset token.
     * @param  destination Address of the destination.
     */
    event TransferAssetRateLimitSet(
        bytes32 indexed key,
        address indexed asset,
        address indexed destination
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets the transfer rate limit for an asset and destination.
     * @param  asset       Address of the asset token.
     * @param  destination Address of the destination.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setTransferRateLimit(
        address asset,
        address destination,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Transfers an ERC-20 asset from the proxy to a destination.
     * @param  asset       Address of the asset token to transfer.
     * @param  destination Address to receive the asset.
     * @param  amount      Amount of asset to transfer (native token decimals).
     */
    function transfer(address asset, address destination, uint256 amount) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for transfer operations.
    function LIMIT_TRANSFER() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured transfer rate limit for an asset and destination.
     * @param  asset       Address of the asset token.
     * @param  destination Address of the destination.
     * @return data        Rate limit data.
     */
    function getTransferRateLimit(address asset, address destination)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
