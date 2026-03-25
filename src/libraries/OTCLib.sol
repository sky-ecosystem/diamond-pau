// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import { makeAddressKey } from "../RateLimitHelpers.sol";

import { FacetBase } from "./FacetBase.sol";

import { IOTCFacet } from "../interfaces/facets/IOTCFacet.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

}

contract OTCFacet is IOTCFacet, FacetBase {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.OTCFacet
    struct FacetStorage {
        mapping (address exchange => State state) states;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.OTCFacet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x381032184f0875ab12ce62a17c374889bec43a2e17ec18539168704ac1f83200;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    bytes32 public constant LIMIT_SWAP = keccak256("LIMIT_OTC_SWAP");

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    function setMaxSlippage(address exchange, uint256 maxSlippage)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(exchange != address(0), "OTCFacet/exchange-zero-address");
        require(maxSlippage > 0,        "OTCFacet/max-slippage-zero");

        _getFacetStorage().states[exchange].maxSlippage = maxSlippage;

        emit OTCMaxSlippageSet(exchange, maxSlippage);
    }

    function setBuffer(address exchange, address buffer)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(exchange != address(0), "OTCFacet/exchange-zero-address");
        require(buffer   != address(0), "OTCFacet/otcBuffer-zero-address");
        require(exchange != buffer,     "OTCFacet/exchange-equals-otcBuffer");

        State storage state = _getFacetStorage().states[exchange];

        // Prevent rotating buffer while a swap is pending and not ready.
        require(state.sentTimestamp == 0 || isSwapReady(exchange), "OTCFacet/swap-in-progress");

        emit OTCBufferSet(exchange, state.buffer = buffer);
    }

    function setRechargeRate(address exchange, uint256 rechargeRate18)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(exchange != address(0), "OTCFacet/exchange-zero-address");

        _getFacetStorage().states[exchange].rechargeRate18 = rechargeRate18;

        emit OTCRechargeRateSet(exchange, rechargeRate18);
    }

    function setIsWhitelisted(address exchange, address asset, bool isWhitelisted)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(exchange != address(0), "OTCFacet/exchange-zero-address");
        require(asset    != address(0), "OTCFacet/asset-zero-address");

        State storage state = _getFacetStorage().states[exchange];

        require(state.buffer != address(0), "OTCFacet/otc-buffer-not-set");

        emit OTCWhitelistedAssetSet(exchange, asset, state.assetWhitelisted[asset] = isWhitelisted);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    function send(address exchange, address assetToSend, uint256 amount)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        require(assetToSend != address(0), "OTCFacet/asset-to-send-zero");
        require(amount > 0,                "OTCFacet/amount-to-send-zero");

        State storage state = _getFacetStorage().states[exchange];

        // NOTE: The only way an asset can be whitelisted is if the buffer is set.
        require(state.assetWhitelisted[assetToSend], "OTCFacet/asset-not-whitelisted");

        // NOTE: This will lose precision for tokens with >18 decimals.
        uint256 sent18 = amount * 1e18 / 10 ** IERC20Like(assetToSend).decimals();

        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(
            makeAddressKey(LIMIT_SWAP, exchange),
            sent18
        );

        require(isSwapReady(exchange), "OTCFacet/last-swap-not-returned");

        state.sent18        = sent18;
        state.sentTimestamp = block.timestamp;
        state.claimed18     = 0;

        emit OTCSwapSent(exchange, state.buffer, assetToSend, amount, sent18);

        _transfer(assetToSend, exchange, amount);
    }

    function claim(address exchange, address assetToClaim)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        require(assetToClaim != address(0), "OTCFacet/asset-to-claim-zero");

        State storage state = _getFacetStorage().states[exchange];

        address buffer = state.buffer;

        require(buffer != address(0),                 "OTCFacet/otc-buffer-not-set");
        require(state.assetWhitelisted[assetToClaim], "OTCFacet/asset-not-whitelisted");

        uint256 amountToClaim   = IERC20Like(assetToClaim).balanceOf(buffer);
        uint256 amountToClaim18 = amountToClaim * 1e18 / 10 ** IERC20Like(assetToClaim).decimals();

        state.claimed18 += amountToClaim18;

        emit OTCClaimed(exchange, buffer, assetToClaim, amountToClaim, amountToClaim18);

        _transferFrom(assetToClaim, buffer, amountToClaim);
    }

    /**********************************************************************************************/
    /*** External View/Pure functions                                                           ***/
    /**********************************************************************************************/

    function getBuffer(address exchange) external view returns (address) {
        return _getFacetStorage().states[exchange].buffer;
    }

    function getMaxSlippage(address exchange) external view returns (uint256) {
        return _getFacetStorage().states[exchange].maxSlippage;
    }

    function getRechargeRate(address exchange) external view returns (uint256) {
        return _getFacetStorage().states[exchange].rechargeRate18;
    }

    function getIsWhitelisted(address exchange, address asset) external view returns (bool) {
        return _getFacetStorage().states[exchange].assetWhitelisted[asset];
    }

    function getState(address exchange)
        external
        view
        returns (uint256 sent18, uint256 sentTimestamp, uint256 claimed18)
    {
        State storage state = _getFacetStorage().states[exchange];
        return (state.sent18, state.sentTimestamp, state.claimed18);
    }

    function getClaimWithRecharge(address exchange) public view returns (uint256) {
        State storage state = _getFacetStorage().states[exchange];

        if (state.sentTimestamp == 0) return 0;

        return state.claimed18 + (block.timestamp - state.sentTimestamp) * state.rechargeRate18;
    }

    function isSwapReady(address exchange) public view returns (bool) {
        State storage state = _getFacetStorage().states[exchange];

        uint256 maxSlippage = state.maxSlippage;

        // If maxSlippages is not set, the exchange is not onboarded.
        if (maxSlippage == 0) return false;

        return getClaimWithRecharge(exchange) >= state.sent18 * maxSlippage / 1e18;
    }

    /**********************************************************************************************/
    /*** Internal functions                                                                     ***/
    /**********************************************************************************************/

    function _transfer(address asset, address destination, uint256 amount) internal {
        bytes memory returnData = IALMProxy(_getSharedControllerStorage().proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transfer, (destination, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "OTCFacet/transfer-failed"
        );
    }

    function _transferFrom(address asset, address source, uint256 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;

        bytes memory returnData = IALMProxy(proxy).doCall(
            asset,
            abi.encodeCall(IERC20Like.transferFrom, (source, proxy, amount))
        );

        require(
            returnData.length == 0 || (returnData.length == 32 && abi.decode(returnData, (bool))),
            "OTCFacet/transferFrom-failed"
        );
    }

}
