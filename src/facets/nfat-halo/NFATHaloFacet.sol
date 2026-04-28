// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib }                   from "../../libraries/ApproveLib.sol";
import { makeAddressAddressUint256Key } from "../../libraries/RateLimitHelpers.sol";

import { IALMProxy }   from "../../interfaces/IALMProxy.sol";
import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { INFATHaloFacet } from "./INFATHaloFacet.sol";

interface IFacilityLike {

    function gem() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);

    function issue(address to, uint256 tokenId, uint256 amount) external;

    function repay(uint256 tokenId, uint256 amount) external;

}

contract NFATHaloFacet is INFATHaloFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.NFATHaloFacet.v1
    struct FacetStorage {
        mapping(uint256 tokenId => Position position) positions;
    }

    // keccak256(abi.encode(uint256(keccak256("sky.pau.storage.NFATHaloFacet.v1")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant FACET_STORAGE_LOCATION =
        0x9374587c30f7383b766c0ada49451c0a4d8cea55cebbd6eec5b0112712b60800;

    function _getFacetStorage() internal pure returns (FacetStorage storage $) {
        assembly {
            $.slot := FACET_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    bytes32 public constant override LIMIT_REPAY_INTEREST =
        keccak256("LIMIT_NFAT_HALO_REPAY_INTEREST");

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /**********************************************************************************************/
    /*** External Interactive Relayer Functions                                                 ***/
    /**********************************************************************************************/

    /// TODO: discuss its own dedicated role.
    /// @inheritdoc INFATHaloFacet
    function issue(address facility, address to, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _getFacetStorage().positions[tokenId].principal = amount;

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.issue, (to, tokenId, amount))
        );

        emit NFATIssue(facility, to, tokenId, amount);
    }

    /// TODO: discuss its own dedicated role.
    /// @inheritdoc INFATHaloFacet
    function repayPrincipal(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        Position storage position = _getFacetStorage().positions[tokenId];

        // Hard cap: cumulative repaid can never exceed the issued principal. No rate limit
        // here — the principal itself is the bound.
        uint256 newRepaid = position.principalRepaid + amount;
        require(newRepaid <= position.principal, "NFATHaloFacet/principal-exceeded");

        position.principalRepaid = newRepaid;

        _doFacilityRepay(facility, tokenId, amount);

        emit NFATRepayPrincipal(facility, tokenId, amount);
    }

    /// TODO: discuss its own dedicated role.
    /// @inheritdoc INFATHaloFacet
    function repayInterest(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        IRateLimits(_getSharedControllerStorage().rateLimits).triggerRateLimitDecrease(
            makeAddressAddressUint256Key(
                LIMIT_REPAY_INTEREST,
                facility,
                IFacilityLike(facility).ownerOf(tokenId),
                tokenId
            ),
            amount
        );

        _doFacilityRepay(facility, tokenId, amount);

        emit NFATRepayInterest(facility, tokenId, amount);
    }

    /**********************************************************************************************/
    /*** External View Functions                                                                ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    function getPrincipal(uint256 tokenId) external view override returns (uint256) {
        return _getFacetStorage().positions[tokenId].principal;
    }

    /// @inheritdoc INFATHaloFacet
    function getPrincipalRepaid(uint256 tokenId) external view override returns (uint256) {
        return _getFacetStorage().positions[tokenId].principalRepaid;
    }

    /**********************************************************************************************/
    /*** Internal Helpers                                                                       ***/
    /**********************************************************************************************/

    function _doFacilityRepay(address facility, uint256 tokenId, uint256 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;

        ApproveLib.approve(IFacilityLike(facility).gem(), proxy, facility, amount);

        IALMProxy(proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.repay, (tokenId, amount))
        );
    }

}
