// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  ISwapFacet
 * @notice TODO
 */
interface ISwapFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    struct AssetConfig {
        uint256 parValue;  // USDS value of one whole unit of the (underlying) asset, 1e18 precision
        bool    isVault;   // True if the asset is an ERC-4626 vault valued through its underlying
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when the swap config of an asset is updated.
     * @param  asset    Address of the asset.
     * @param  parValue USDS value of one whole unit of the (underlying) asset, 1e18 precision.
     * @param  isVault  True if the asset is an ERC-4626 vault valued through its underlying.
     */
    event SwapAssetConfigSet(address indexed asset, uint256 parValue, bool isVault);

    /**
     * @notice Emitted on the counterparty PAU when it fills a swap.
     * @param  counterparty  Address of the initiating controller.
     * @param  receiveAsset  Address of the asset received from the initiator.
     * @param  sendAsset     Address of the asset sent to the initiator.
     * @param  receiveAmount Amount received from the initiator (native token decimals).
     * @param  sendAmount    Amount sent to the initiator (native token decimals).
     */
    event SwapFilled(
        address indexed counterparty,
        address indexed receiveAsset,
        address indexed sendAsset,
        uint256         receiveAmount,
        uint256         sendAmount
    );

    /**
     * @notice Emitted on the initiating PAU when it executes a swap.
     * @param  counterparty  Address of the counterparty controller.
     * @param  sendAsset     Address of the asset sent to the counterparty.
     * @param  receiveAsset  Address of the asset received from the counterparty.
     * @param  sendAmount    Amount sent to the counterparty (native token decimals).
     * @param  receiveAmount Amount received from the counterparty (native token decimals).
     */
    event Swapped(
        address indexed counterparty,
        address indexed sendAsset,
        address indexed receiveAsset,
        uint256         sendAmount,
        uint256         receiveAmount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Fills a swap initiated by a counterparty controller. The counterparty has already
     *         sent `receiveAmount` of `receiveAsset` to this proxy. Sends `sendAmount` of
     *         `sendAsset` back to the counterparty proxy. Callable only by an account with
     *         `SWAP_COUNTERPARTY_ROLE`.
     * @param  receiveAsset  Address of the asset received from the initiator.
     * @param  sendAsset     Address of the asset to send to the initiator.
     * @param  receiveAmount Amount received from the initiator (native token decimals).
     * @param  sendAmount    Amount to send to the initiator (native token decimals). Must not
     *                       exceed this PAU's own quote for `receiveAmount`.
     */
    function fillSwap(
        address receiveAsset,
        address sendAsset,
        uint256 receiveAmount,
        uint256 sendAmount
    ) external;

    /**
     * @notice Sets the swap config of an asset. Used by governance to set or haircut par value.
     * @param  asset    Address of the asset.
     * @param  parValue USDS value of one whole unit of the (underlying) asset, 1e18 precision.
     * @param  isVault  True if the asset is an ERC-4626 vault valued through its underlying.
     */
    function setAssetConfig(address asset, uint256 parValue, bool isVault) external;

    /**
     * @notice Swaps `sendAmount` of `sendAsset` for `receiveAsset` with a counterparty PAU.
     * @param  counterparty     Address of the counterparty controller.
     * @param  sendAsset        Address of the asset to send.
     * @param  receiveAsset     Address of the asset to receive.
     * @param  sendAmount       Amount to send (native token decimals).
     * @param  minReceiveAmount Minimum amount to receive (native token decimals).
     * @return receiveAmount    Amount received (native token decimals).
     */
    function swap(
        address counterparty,
        address sendAsset,
        address receiveAsset,
        uint256 sendAmount,
        uint256 minReceiveAmount
    ) external returns (uint256 receiveAmount);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /// @notice Role identifier for counterparty controllers allowed to call `fillSwap`.
    function SWAP_COUNTERPARTY_ROLE() external pure returns (bytes32);

    /**
     * @notice Returns the swap config of an asset.
     * @param  asset    Address of the asset.
     * @return parValue USDS value of one whole unit of the (underlying) asset, 1e18 precision.
     * @return isVault  True if the asset is an ERC-4626 vault valued through its underlying.
     */
    function getAssetConfig(address asset) external view returns (uint256 parValue, bool isVault);

    /**
     * @notice Returns the amount of `receiveAsset` for `sendAmount` of `sendAsset` at par value.
     * @param  sendAsset     Address of the asset to send.
     * @param  receiveAsset  Address of the asset to receive.
     * @param  sendAmount    Amount to send (native token decimals).
     * @return receiveAmount Amount to receive (native token decimals), rounded down.
     */
    function getSwapQuote(address sendAsset, address receiveAsset, uint256 sendAmount)
        external
        view
        returns (uint256 receiveAmount);

    /**
     * @notice Returns the derived swap rate limit key. Each PAU limits the asset it sends.
     * @param  counterparty Address of the counterparty controller.
     * @param  sendAsset    Address of the asset sent by this PAU.
     * @param  receiveAsset Address of the asset received by this PAU.
     * @return key          Derived rate limit key.
     */
    function getSwapRateLimitKey(address counterparty, address sendAsset, address receiveAsset)
        external
        pure
        returns (bytes32 key);

}
