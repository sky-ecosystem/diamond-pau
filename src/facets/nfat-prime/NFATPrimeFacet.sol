// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }     from "../../libraries/ApproveLib.sol";
import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { INFATPrimeFacet } from "./INFATPrimeFacet.sol";

interface IFacilityLike {

    function gem() external view returns (address);

    function subscribe(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount) external;

    function collect(uint256 tokenId, uint256 amount) external;

}

contract NFATPrimeFacet is INFATPrimeFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATPrimeFacet
    bytes32 public constant override LIMIT_SUBSCRIBE = keccak256("LIMIT_NFAT_PRIME_SUBSCRIBE");

    /// @inheritdoc INFATPrimeFacet
    bytes32 public constant override LIMIT_COLLECT   = keccak256("LIMIT_NFAT_PRIME_COLLECT");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATPrimeFacet
    function subscribe(address facility, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        IRateLimits($.rateLimits).triggerRateLimitDecrease(
            makeAddressKey(LIMIT_SUBSCRIBE, facility),
            amount
        );

        address proxy = $.proxy;

        ApproveLib.approve(IFacilityLike(facility).gem(), proxy, facility, amount);

        IALMProxy(proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.subscribe, (amount, data))
        );

        emit NFATSubscribe(facility, amount);
    }

    // NOTE: withdraw() cancels queued deposits before issuance. Since the funds have not yet been
    // deployed into an issued NFAT position, this path refills LIMIT_SUBSCRIBE on exit, mirroring
    // facets such as ERC4626 and Aave where returned capital restores deposit capacity. No separate
    // withdraw limit is used here because this action only returns unsubscribed capital.
    /// @inheritdoc INFATPrimeFacet
    function withdraw(address facility, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        IALMProxy($.proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.withdraw, (amount))
        );

        IRateLimits($.rateLimits).triggerRateLimitIncrease(
            makeAddressKey(LIMIT_SUBSCRIBE, facility),
            amount
        );

        emit NFATWithdraw(facility, amount);
    }

    // NOTE: collect() returns repaid funds from an issued NFAT position back to the proxy.
    // LIMIT_COLLECT bounds the rate at which funds can be pulled from a facility, consistent with
    // the repo's broader pattern of rate-limiting return flows from external systems. Because the
    // collected funds are back on the proxy and available for redeployment, this path also refills
    // LIMIT_SUBSCRIBE.
    /// @inheritdoc INFATPrimeFacet
    function collect(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        IRateLimits rateLimits = IRateLimits($.rateLimits);

        rateLimits.triggerRateLimitDecrease(
            makeAddressKey(LIMIT_COLLECT, facility),
            amount
        );

        IALMProxy($.proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.collect, (tokenId, amount))
        );

        rateLimits.triggerRateLimitIncrease(
            makeAddressKey(LIMIT_SUBSCRIBE, facility),
            amount
        );

        emit NFATCollect(facility, tokenId, amount);
    }

}
