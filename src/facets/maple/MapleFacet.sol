// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { IMapleFacet } from "./IMapleFacet.sol";

interface IMapleTokenLike {

    function requestRedeem(uint256 shares, address receiver) external;

    function removeShares(uint256 shares, address receiver) external;

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

}

contract MapleFacet is IMapleFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc IMapleFacet
    bytes32 public constant override LIMIT_REDEEM = keccak256("LIMIT_MAPLE_REDEEM");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc IMapleFacet
    function setRedeemRateLimit(
        address mapleToken,
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
        require(mapleToken != address(0), "MapleFacet/maple-token-zero-address");

        bytes32 key = _getRedeemRateLimitKey(mapleToken);

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit MapleRedeemRateLimitSet(key, mapleToken);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc IMapleFacet
    function requestRedemption(address mapleToken, uint256 shares)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _decreaseRateLimit(
            _getRedeemRateLimitKey(mapleToken),
            IMapleTokenLike(mapleToken).convertToAssets(shares)
        );

        address proxy = _getSharedControllerStorage().proxy;

        IALMProxy(proxy).doCall(
            mapleToken,
            abi.encodeCall(IMapleTokenLike.requestRedeem, (shares, proxy))
        );

        emit MapleRequestRedemption(mapleToken, shares);
    }

    /// @inheritdoc IMapleFacet
    function cancelRedemption(address mapleToken, uint256 shares)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        require(
            _rateLimitExists(_getRedeemRateLimitKey(mapleToken)),
            "MapleFacet/invalid-action"
        );

        address proxy = _getSharedControllerStorage().proxy;

        IALMProxy(proxy).doCall(
            mapleToken,
            abi.encodeCall(IMapleTokenLike.removeShares, (shares, proxy))
        );

        emit MapleCancelRedemption(mapleToken, shares);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc IMapleFacet
    function getRedeemRateLimit(address mapleToken)
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(_getRedeemRateLimitKey(mapleToken));
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getRedeemRateLimitKey(address mapleToken) internal pure returns (bytes32) {
        return makeAddressKey(LIMIT_REDEEM, mapleToken);
    }

}
