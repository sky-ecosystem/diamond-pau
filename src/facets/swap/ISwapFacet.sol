// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISwapFacet
 * @notice PAU facet for atomic swaps of ERC-20 assets at an admin-set par value between the proxy
 *         and a counterparty PAU proxy. The proxy transfers `assetIn` to the counterparty and
 *         pulls `assetOut` from the counterparty in the same call, using a standing allowance that
 *         the counterparty's admin grants to this proxy. Par values express the USDS value of one
 *         whole unit of each asset in 1e18 precision (1e18 = 1 USDS). Rate limited per
 *         (assetIn, assetOut, counterparty) route.
 */
interface ISwapFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct AssetParameters {
        uint256 parValue;  // USDS value of one whole unit of the asset, 1e18 precision
        uint8   decimals;  // Snapshot of the asset's decimals at configuration time
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when the standing allowance of an asset from the proxy to a counterparty is
     *         updated.
     * @param  asset        Address of the asset token.
     * @param  counterparty Address of the counterparty proxy granted the allowance.
     * @param  allowance    New allowance in native token decimals.
     */
    event SwapAllowanceSet(
        address indexed asset,
        address indexed counterparty,
        uint256         allowance
    );

    /**
     * @notice Emitted when a swap is executed.
     * @param  counterparty Address of the counterparty proxy.
     * @param  assetIn      Address of the asset sent to the counterparty.
     * @param  assetOut     Address of the asset pulled from the counterparty.
     * @param  amountIn     Amount of `assetIn` sent in native token decimals.
     * @param  amountOut    Amount of `assetOut` received in native token decimals.
     */
    event SwapExecuted(
        address indexed counterparty,
        address indexed assetIn,
        address indexed assetOut,
        uint256         amountIn,
        uint256         amountOut
    );

    /**
     * @notice Emitted when the par value of an asset is updated.
     * @param  asset    Address of the asset token.
     * @param  parValue New par value in 1e18 precision (1e18 = 1 USDS per whole unit). Zero
     *                  disables the asset.
     * @param  decimals Decimals of the asset snapshotted at configuration time.
     */
    event SwapParValueSet(address indexed asset, uint256 parValue, uint8 decimals);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Sets the standing allowance of an asset from the proxy to a counterparty proxy. The
     *         allowance bounds what the counterparty's swap facet can pull from this proxy.
     * @param  asset        Address of the asset token.
     * @param  counterparty Address of the counterparty proxy to grant the allowance to.
     * @param  allowance    Allowance in native token decimals. Zero revokes the allowance.
     */
    function approve(address asset, address counterparty, uint256 allowance) external;

    /**
     * @notice Sets the par value of an asset and snapshots its decimals. Both assets of a swap
     *         must have a nonzero par value.
     * @param  asset    Address of the asset token.
     * @param  parValue Par value in 1e18 precision (1e18 = 1 USDS per whole unit). Zero disables
     *                  the asset.
     */
    function setParValue(address asset, uint256 parValue) external;

    /**
     * @notice Atomically sends `amountIn` of `assetIn` from the proxy to the counterparty and
     *         pulls the par-equivalent amount of `assetOut` from the counterparty to the proxy.
     *         Decreases the (assetIn, assetOut, counterparty) swap rate limit by `amountIn` and
     *         restores the (assetOut, assetIn, counterparty) swap rate limit by `amountOut` when
     *         that key is configured.
     * @param  counterparty Address of the counterparty proxy.
     * @param  assetIn      Address of the asset to send.
     * @param  assetOut     Address of the asset to receive.
     * @param  amountIn     Amount of `assetIn` to send in native token decimals.
     * @param  minAmountOut Minimum amount of `assetOut` to receive in native token decimals.
     * @return amountOut    Amount of `assetOut` received in native token decimals.
     */
    function swap(
        address counterparty,
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut
    )
        external
        returns (uint256 amountOut);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the amount of `assetOut` received for `amountIn` of `assetIn` at the
     *         configured par values, rounded down. Reverts if either par value is unset.
     * @param  assetIn   Address of the asset sent.
     * @param  assetOut  Address of the asset received.
     * @param  amountIn  Amount of `assetIn` in native token decimals.
     * @return amountOut Amount of `assetOut` in native token decimals.
     */
    function getAmountOut(address assetIn, address assetOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);

    /**
     * @notice Returns the configured par value and decimals snapshot of an asset.
     * @param  asset    Address of the asset token.
     * @return parValue Par value in 1e18 precision. Zero if not set.
     * @return decimals Decimals snapshotted when the par value was set.
     */
    function getAssetParameters(address asset)
        external
        view
        returns (uint256 parValue, uint8 decimals);

    /**
     * @notice Returns the derived swap rate limit key for a route.
     * @param  assetIn      Address of the asset sent.
     * @param  assetOut     Address of the asset received.
     * @param  counterparty Address of the counterparty proxy.
     * @return key          Derived rate limit key.
     */
    function getSwapRateLimitKey(address assetIn, address assetOut, address counterparty)
        external
        pure
        returns (bytes32 key);

}
