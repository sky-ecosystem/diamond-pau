// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }            from "../../libraries/ApproveLib.sol";
import { makeAddressAddressKey } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { INFATHaloFacet } from "./INFATHaloFacet.sol";

interface IFacilityLike {

    function gem() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);

    function repay(uint256 tokenId, uint256 amount) external;

}

contract NFATHaloFacet is INFATHaloFacet, Facet {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    bytes32 public constant override LIMIT_REPAY = keccak256("LIMIT_NFAT_HALO_REPAY");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    function repay(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        SharedControllerStorage storage $ = _getSharedControllerStorage();

        IRateLimits($.rateLimits).triggerRateLimitDecrease(
            makeAddressAddressKey(
                LIMIT_REPAY,
                facility,
                IFacilityLike(facility).ownerOf(tokenId)
            ),
            amount
        );

        address proxy = $.proxy;

        ApproveLib.approve(IFacilityLike(facility).gem(), proxy, facility, amount);

        IALMProxy(proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.repay, (tokenId, amount))
        );

        emit NFATRepay(facility, tokenId, amount);
    }

}
