// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISwapAssetFacet
 * @notice PAU facet for swapping ERC-20 assets 1:1 between ALMProxy controllers, adjusting for
 *         token decimals. Rate limited per (`assetOut`, `counterpartyProxy`, `assetIn`) tuple, in
 *         units of the asset sent by the respective side.
 */
interface ISwapAssetFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an ERC-20 asset swap is executed.
     * @param  counterpartyProxy Address of the ALMProxy counterparty.
     * @param  assetOut          Address of the asset token that was sent.
     * @param  assetIn           Address of the asset token that was received.
     * @param  amountOut         Amount of `assetOut` that was sent (`assetOut` decimals).
     * @param  amountIn          Amount of `assetIn` that was received (`assetIn` decimals).
     */
    event SwapAssetSwap(
        address indexed counterpartyProxy,
        address indexed assetOut,
        address indexed assetIn,
        uint256         amountOut,
        uint256         amountIn
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Initiates an ERC-20 asset swap with the counterparty controller. The amount received
     *         is `amountOut` converted to `assetIn` decimals. Decreases the rate limit by
     *         `amountOut`.
     * @param  counterpartyController Address of the counterparty's controller.
     * @param  assetOut               Address of the asset token to send.
     * @param  assetIn                Address of the asset token to receive.
     * @param  amountOut              Amount of `assetOut` to send (`assetOut` decimals).
     */
    function initiateSwap(
        address counterpartyController,
        address assetOut,
        address assetIn,
        uint256 amountOut
    )
        external;

    /**
     * @notice Completes an ERC-20 asset swap. Called by the counterparty proxy, which is
     *         permissioned through the rate limit key. The amount received is `amountOut` converted
     *         to `assetIn` decimals. Decreases the rate limit by `amountOut`.
     * @param  assetOut  Address of the asset token to send.
     * @param  assetIn   Address of the asset token to receive.
     * @param  amountOut Amount of `assetOut` to send (`assetOut` decimals).
     */
    function completeSwap(address assetOut, address assetIn, uint256 amountOut) external;

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
