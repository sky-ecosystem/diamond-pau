// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { ApproveLib } from "../../libraries/ApproveLib.sol";

import { IALMProxy } from "../../interfaces/IALMProxy.sol";

import { IFacet } from "../IFacet.sol";

import { Facet } from "../Facet.sol";

import { INFATHaloFacet } from "./INFATHaloFacet.sol";

interface IFacilityLike {

    function gem() external view returns (address);

    function issue(address to, uint256 tokenId, uint256 amount) external;

    function repay(uint256 tokenId, uint256 amount) external;

}

contract NFATHaloFacet is INFATHaloFacet, Facet {

    /**********************************************************************************************/
    /*** Facet Storage Domain                                                                   ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:sky.pau.storage.NFATHaloFacet.v1
    struct FacetStorage {
        mapping (address facility => Parameters params)                          parameters;
        mapping (address facility => FacilityState state)                        states;
        mapping (address facility => mapping (uint256 tokenId => Position pos)) positions;
    }

    struct Parameters {
        uint256 annualGrowthRate; // 1e18 = 100% APR
    }

    struct FacilityState {
        uint256 interestIndex; // Cumulative 1e18-scaled interest per unit of principal
        uint256 lastUpdated;
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

    uint256 internal constant _INTEREST_RATE_PRECISION = 1e18;
    uint256 internal constant _YEAR                    = 365 days;

    /// @inheritdoc IFacet
    string public constant override VERSION = "1.0.0";

    /// @inheritdoc INFATHaloFacet
    bytes32 public constant override NFAT_BEACON_ROLE = keccak256("NFAT_BEACON_ROLE");

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    function setAnnualGrowthRate(address facility, uint256 annualGrowthRate)
        external
        override
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(facility != address(0), "NFATHaloFacet/facility-zero-address");

        _checkpointFacility(facility);

        _getFacetStorage().parameters[facility].annualGrowthRate = annualGrowthRate;

        emit NFATHaloAnnualGrowthRateSet(facility, annualGrowthRate);
    }

    /**********************************************************************************************/
    /*** External Interactive NFAT Beacon Functions                                             ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    function issue(address facility, address to, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(NFAT_BEACON_ROLE)
    {
        require(facility != address(0), "NFATHaloFacet/facility-zero-address");

        FacetStorage storage $ = _getFacetStorage();

        Position storage position = $.positions[facility][tokenId];

        require(!position.issued, "NFATHaloFacet/position-exists");

        _checkpointFacility(facility);

        position.issued        = true;
        position.principal     = amount;
        position.interestIndex = $.states[facility].interestIndex;

        IALMProxy(_getSharedControllerStorage().proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.issue, (to, tokenId, amount))
        );

        emit NFATHaloIssue(facility, to, tokenId, amount);
    }

    /// @inheritdoc INFATHaloFacet
    function repayPrincipal(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(NFAT_BEACON_ROLE)
    {
        require(facility != address(0), "NFATHaloFacet/facility-zero-address");
        require(amount > 0,              "NFATHaloFacet/zero-amount");

        Position storage position = _checkpointPosition(facility, tokenId);

        uint256 principalOutstanding = position.principal - position.principalRepaid;
        require(amount <= principalOutstanding, "NFATHaloFacet/principal-exceeded");

        position.principalRepaid += amount;

        _doFacilityRepay(facility, tokenId, amount);

        emit NFATHaloRepayPrincipal(facility, tokenId, amount);
    }

    /// @inheritdoc INFATHaloFacet
    function repayInterest(address facility, uint256 tokenId, uint256 amount)
        external
        override
        nonReentrant
        onlyRole(NFAT_BEACON_ROLE)
    {
        require(facility != address(0), "NFATHaloFacet/facility-zero-address");
        require(amount > 0,              "NFATHaloFacet/zero-amount");

        Position storage position = _checkpointPosition(facility, tokenId);

        require(amount <= position.accruedInterest, "NFATHaloFacet/interest-exceeded");

        position.accruedInterest -= amount;

        _doFacilityRepay(facility, tokenId, amount);

        emit NFATHaloRepayInterest(facility, tokenId, amount);
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc INFATHaloFacet
    function getAnnualGrowthRate(address facility) external view override returns (uint256) {
        return _getFacetStorage().parameters[facility].annualGrowthRate;
    }

    /// @inheritdoc INFATHaloFacet
    function getInterestIndex(address facility) external view override returns (uint256) {
        return _getCurrentInterestIndex(facility);
    }

    /// @inheritdoc INFATHaloFacet
    function getPosition(address facility, uint256 tokenId)
        external
        view
        override
        returns (Position memory)
    {
        return _getFacetStorage().positions[facility][tokenId];
    }

    /// @inheritdoc INFATHaloFacet
    function getPrincipal(address facility, uint256 tokenId) external view override returns (uint256) {
        return _getFacetStorage().positions[facility][tokenId].principal;
    }

    /// @inheritdoc INFATHaloFacet
    function getPrincipalRepaid(address facility, uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        return _getFacetStorage().positions[facility][tokenId].principalRepaid;
    }

    /// @inheritdoc INFATHaloFacet
    function getPrincipalOutstanding(address facility, uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        Position storage position = _getFacetStorage().positions[facility][tokenId];
        return position.principal - position.principalRepaid;
    }

    /// @inheritdoc INFATHaloFacet
    function getInterestAvailable(address facility, uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        Position storage position = _getFacetStorage().positions[facility][tokenId];
        if (!position.issued) return 0;

        uint256 principalOutstanding = position.principal - position.principalRepaid;
        uint256 deltaIndex           = _getCurrentInterestIndex(facility) - position.interestIndex;

        return position.accruedInterest + principalOutstanding * deltaIndex / _INTEREST_RATE_PRECISION;
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _checkpointFacility(address facility) internal {
        FacetStorage  storage $     = _getFacetStorage();
        FacilityState storage state = $.states[facility];

        uint256 lastUpdated = state.lastUpdated;
        if (lastUpdated == block.timestamp) return;

        if (lastUpdated != 0) {
            state.interestIndex = _getCurrentInterestIndex(facility);
        }

        state.lastUpdated = block.timestamp;
    }

    function _checkpointPosition(address facility, uint256 tokenId)
        internal
        returns (Position storage position)
    {
        _checkpointFacility(facility);

        FacetStorage storage $ = _getFacetStorage();

        position = $.positions[facility][tokenId];
        require(position.issued, "NFATHaloFacet/position-not-found");

        uint256 currentIndex = $.states[facility].interestIndex;
        uint256 deltaIndex   = currentIndex - position.interestIndex;

        if (deltaIndex > 0) {
            uint256 principalOutstanding = position.principal - position.principalRepaid;
            position.interestIndex       = currentIndex;
            position.accruedInterest     += principalOutstanding * deltaIndex / _INTEREST_RATE_PRECISION;
        }
    }

    function _doFacilityRepay(address facility, uint256 tokenId, uint256 amount) internal {
        address proxy = _getSharedControllerStorage().proxy;
        address gem   = IFacilityLike(facility).gem();

        ApproveLib.approve(gem, proxy, facility, amount);

        IALMProxy(proxy).doCall(
            facility,
            abi.encodeCall(IFacilityLike.repay, (tokenId, amount))
        );

        ApproveLib.approve(gem, proxy, facility, 0);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    function _getCurrentInterestIndex(address facility) internal view returns (uint256) {
        FacetStorage storage $     = _getFacetStorage();

        FacilityState storage state = $.states[facility];

        uint256 lastUpdated = state.lastUpdated;
        if (lastUpdated == 0) return state.interestIndex;

        return
            state.interestIndex +
            $.parameters[facility].annualGrowthRate * (block.timestamp - lastUpdated) / _YEAR;
    }

}
