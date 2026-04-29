// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { ISuperstateFacet } from "./ISuperstateFacet.sol";

interface IUSTBLike {

    function subscribe(uint256 inAmount, address stablecoin) external;

}

// NOTE: This contract is only compatible with USTB and USDC.
contract SuperstateFacet is ISuperstateFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc ISuperstateFacet
    bytes32 public constant override LIMIT_SUBSCRIBE = keccak256("LIMIT_SUPERSTATE_SUBSCRIBE");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** Declarations                                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISuperstateFacet
    address public immutable override usdc;

    /// @inheritdoc ISuperstateFacet
    address public immutable override ustb;

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor(address usdc_, address ustb_) {
        require(usdc_ != address(0), "SuperstateFacet/zero-usdc");
        require(ustb_ != address(0), "SuperstateFacet/zero-ustb");

        usdc = usdc_;
        ustb = ustb_;
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISuperstateFacet
    function setSubscribeRateLimit(
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
        bytes32 key = LIMIT_SUBSCRIBE;

        _setRateLimit(key, maxAmount, slope, lastAmount, lastUpdated);

        emit SuperstateSubscribeRateLimitSet(key);
    }

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc ISuperstateFacet
    function subscribe(uint256 usdcAmount) external override nonReentrant onlyRole(RELAYER_ROLE) {
        _decreaseRateLimit(LIMIT_SUBSCRIBE, usdcAmount);

        address proxy = _getSharedControllerStorage().proxy;

        ApproveLib.approve(usdc, proxy, ustb, usdcAmount);

        IALMProxy(proxy).doCall(ustb, abi.encodeCall(IUSTBLike.subscribe, (usdcAmount, usdc)));

        emit SuperstateSubscribe(usdcAmount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISuperstateFacet
    function subscribeRateLimit()
        external
        view
        override
        returns (IRateLimits.RateLimitData memory data)
    {
        return _getRateLimit(LIMIT_SUBSCRIBE);
    }

}
