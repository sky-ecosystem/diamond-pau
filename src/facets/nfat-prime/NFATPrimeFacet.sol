// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }     from "../../libraries/ApproveLib.sol";
import { makeAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

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

    bytes32 internal constant _LIMIT_SUBSCRIBE = keccak256("LIMIT_NFAT_PRIME_SUBSCRIBE");
    bytes32 internal constant _LIMIT_COLLECT   = keccak256("LIMIT_NFAT_PRIME_COLLECT");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Allocator Functions                                               ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATPrimeFacet
    function subscribe(address facility, uint256 amount, bytes calldata data)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        require(facility != address(0), "NFATPrimeFacet/facility-zero-address");

        if (amount > 0) {
            _decreaseRateLimit(getSubscribeRateLimitKey(facility), amount);
        }

        address proxy = _getSharedControllerStorage().proxy;

        if (amount > 0) {
            ApproveLib.approve(IFacilityLike(facility).gem(), proxy, facility, amount);
        }

        IALMProxy(proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.subscribe, (amount, data))
        );

        if (amount > 0) {
            ApproveLib.approve(IFacilityLike(facility).gem(), proxy, facility, 0);
        }

        emit NFATPrimeSubscribe(facility, amount, data);
    }

    /// @inheritdoc INFATPrimeFacet
    function withdraw(address facility, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        require(facility != address(0), "NFATPrimeFacet/facility-zero-address");

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.withdraw, (amount))
        );

        _tryIncreaseRateLimit(getSubscribeRateLimitKey(facility), amount);

        emit NFATPrimeWithdraw(facility, amount);
    }

    /// @inheritdoc INFATPrimeFacet
    function collect(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(ALLOCATOR_ROLE)
    {
        require(facility != address(0), "NFATPrimeFacet/facility-zero-address");

        _decreaseRateLimit(getCollectRateLimitKey(facility), amount);

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.collect, (tokenId, amount))
        );

        _tryIncreaseRateLimit(getSubscribeRateLimitKey(facility), amount);

        emit NFATPrimeCollect(facility, tokenId, amount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATPrimeFacet
    function getSubscribeRateLimitKey(address facility) public pure override returns (bytes32) {
        return makeAddressKey(_LIMIT_SUBSCRIBE, facility);
    }

    /// @inheritdoc INFATPrimeFacet
    function getCollectRateLimitKey(address facility) public pure override returns (bytes32) {
        return makeAddressKey(_LIMIT_COLLECT, facility);
    }

}
