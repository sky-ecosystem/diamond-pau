// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISwapAssetFacet
 * @notice PAU facet for swapping ERC-20 assets between ALMProxy controllers.
 *         Rate limited per (counterparty-proxy, asset-out, asset-in) tuple.
 */
interface ISwapAssetFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a completed ERC-20 asset swap was initiated from this controller.
     * @param  counterpartyProxy Address of the ALMProxy counterparty.
     * @param  assetOut          Address of the asset token that was sent.
     * @param  assetIn           Address of the asset token that was received.
     * @param  amount            Amount of each asset that was swapped (native token decimals).
     */
    event SwapAssetSwapInitiated(
        address indexed counterpartyProxy,
        address indexed assetOut,
        address indexed assetIn,
        uint256         amount
    );

    /**
     * @notice Emitted when a completed ERC-20 asset swap was completed at this controller.
     * @param  counterpartyProxy Address of the ALMProxy counterparty.
     * @param  assetOut          Address of the asset token that was sent.
     * @param  assetIn           Address of the asset token that was received.
     * @param  amount            Amount of each asset that was swapped (native token decimals).
     */
    event SwapAssetSwapCompleted(
        address indexed counterpartyProxy,
        address indexed assetOut,
        address indexed assetIn,
        uint256         amount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Initiates an ERC-20 asset swap.
     * @param  counterpartyController Address of the counterparty's controller.
     * @param  assetOut               Address of the asset token that was sent.
     * @param  assetIn                Address of the asset token that was received.
     * @param  amount                 Amount of each asset that was swapped (native token decimals).
     */
    function initiateSwap(
        address counterpartyController,
        address assetOut,
        address assetIn,
        uint256 amount
    )
        external;

    /**
     * @notice Completes an ERC-20 asset swap. Called by the counterparty.
     * @param  assetOut Address of the asset token that was sent.
     * @param  assetIn  Address of the asset token that was received.
     * @param  amount   Amount of each asset that was swapped (native token decimals).
     */
    function completeSwap(address assetOut, address assetIn, uint256 amount) external;

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the swap rate limit key.
     * @param  assetOut          Address of the asset token that was sent.
     * @param  counterpartyProxy Address of the counterparty proxy.
     * @param  assetIn           Address of the asset token that was received.
     * @return key               Swap rate limit key.
     */
    function getSwapRateLimitKey(address assetOut, address counterpartyProxy, address assetIn)
        external
        pure
        returns (bytes32 key);

}
