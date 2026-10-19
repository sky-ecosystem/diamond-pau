// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { makeAddressAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IController } from "../../interfaces/IController.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISwapFacet } from "./ISwapFacet.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);

}

interface IERC4626Like {

    function asset() external view returns (address);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

}

contract SwapFacet is ISwapFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.SwapFacet.v1
    struct FacetStorage {
        mapping (address asset => AssetConfig config) assetConfigs;
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

    bytes32 internal constant _LIMIT_SWAP = keccak256("LIMIT_PAU_SWAP");

    /// @inheritdoc ISwapFacet
    bytes32 public constant override SWAP_COUNTERPARTY_ROLE = keccak256("SWAP_COUNTERPARTY_ROLE");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function setAssetConfig(address asset, uint256 parValue, bool isVault)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(asset != address(0), "SwapFacet/asset-zero-address");

        _getFacetStorage().assetConfigs[asset] = AssetConfig(parValue, isVault);

        emit SwapAssetConfigSet(asset, parValue, isVault);
    }

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function swap(
        address counterparty,
        address sendAsset,
        address receiveAsset,
        uint256 sendAmount,
        uint256 minReceiveAmount
    )
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
        returns (uint256 receiveAmount)
    {
        require(sendAmount > 0, "SwapFacet/zero-amount");

        _decreaseRateLimit(getSwapRateLimitKey(counterparty, sendAsset, receiveAsset), sendAmount);

        receiveAmount = getSwapQuote(sendAsset, receiveAsset, sendAmount);

        require(receiveAmount > 0,                "SwapFacet/zero-receive-amount");
        require(receiveAmount >= minReceiveAmount, "SwapFacet/slippage-too-high");

        _transfer(sendAsset, IController(counterparty).proxy(), sendAmount);

        // NOTE: The counterparty validates `receiveAmount` against its own par values and
        //       reverts if it would pay more than its own quote.
        ISwapFacet(counterparty).fillSwap(sendAsset, receiveAsset, sendAmount, receiveAmount);

        emit Swapped(counterparty, sendAsset, receiveAsset, sendAmount, receiveAmount);
    }

    /**********************************************************************************************/
    /*** External Interactive Counterparty Functions                                            ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function fillSwap(
        address receiveAsset,
        address sendAsset,
        uint256 receiveAmount,
        uint256 sendAmount
    )
        external
        override
        nonReentrant
        onlyRole(SWAP_COUNTERPARTY_ROLE)
    {
        _decreaseRateLimit(getSwapRateLimitKey(msg.sender, sendAsset, receiveAsset), sendAmount);

        require(
            sendAmount <= getSwapQuote(receiveAsset, sendAsset, receiveAmount),
            "SwapFacet/exceeds-quote"
        );

        _transfer(sendAsset, IController(msg.sender).proxy(), sendAmount);

        emit SwapFilled(msg.sender, receiveAsset, sendAsset, receiveAmount, sendAmount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISwapFacet
    function getAssetConfig(address asset)
        external
        view
        override
        returns (uint256 parValue, bool isVault)
    {
        AssetConfig storage config = _getFacetStorage().assetConfigs[asset];
        return (config.parValue, config.isVault);
    }

    /// @inheritdoc ISwapFacet
    function getSwapQuote(address sendAsset, address receiveAsset, uint256 sendAmount)
        public
        view
        override
        returns (uint256)
    {
        return _fromValue(receiveAsset, _toValue(sendAsset, sendAmount));
    }

    /// @inheritdoc ISwapFacet
    function getSwapRateLimitKey(address counterparty, address sendAsset, address receiveAsset)
        public
        pure
        override
        returns (bytes32)
    {
        return makeAddressAddressAddressKey(_LIMIT_SWAP, counterparty, sendAsset, receiveAsset);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _transfer(address asset, address destination, uint256 amount) internal {
        bytes memory returnData = IALMProxy(_getSharedControllerStorage().proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transfer, (destination, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "SwapFacet/transfer-failed"
        );
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    // Converts an asset amount to its USDS value (18 decimals), rounded down.
    function _toValue(address asset, uint256 amount) internal view returns (uint256) {
        AssetConfig storage config = _getAssetConfig(asset);

        if (config.isVault) {
            amount = IERC4626Like(asset).convertToAssets(amount);
            asset  = IERC4626Like(asset).asset();
        }

        return amount * config.parValue / 10 ** IERC20Like(asset).decimals();
    }

    // Converts a USDS value (18 decimals) to an asset amount, rounded down.
    function _fromValue(address asset, uint256 value) internal view returns (uint256) {
        AssetConfig storage config = _getAssetConfig(asset);

        address underlying = config.isVault ? IERC4626Like(asset).asset() : asset;

        uint256 amount = value * 10 ** IERC20Like(underlying).decimals() / config.parValue;

        return config.isVault ? IERC4626Like(asset).convertToShares(amount) : amount;
    }

    function _getAssetConfig(address asset) internal view returns (AssetConfig storage config) {
        config = _getFacetStorage().assetConfigs[asset];

        require(config.parValue > 0, "SwapFacet/asset-not-configured");
    }

}
