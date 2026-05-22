// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  INFATHaloFacet
 * @notice PAU facet for the Halo (recipient) side of an NFAT facility. Issues NFT positions
 *         against prior subscriptions, accrues per-facility interest via a configurable annual
 *         growth rate, and exposes split repayment flows for principal and interest. Operational
 *         entry points are gated on NFAT_BEACON_ROLE.
 */
interface INFATHaloFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Per-NFAT bookkeeping recorded by this facet.
     * @param  issued          True once `issue` has been called for this position; subsequent
     *                         issues for the same (facility, tokenId) revert.
     * @param  principal       Amount pulled from the facility on `issue`. Immutable post-issue.
     * @param  principalRepaid Cumulative principal repaid via `repayPrincipal`; <= principal.
     * @param  accruedInterest Interest accrued at the last checkpoint, net of `repayInterest`.
     * @param  interestIndex   Facility-wide interest index recorded at the last checkpoint.
     */
    struct Position {
        bool    issued;
        uint256 principal;
        uint256 principalRepaid;
        uint256 accruedInterest;
        uint256 interestIndex;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when the annual growth rate (1e18-scaled APR) for a facility is updated.
     * @param  facility         Address of the NFAT facility.
     * @param  annualGrowthRate New annual growth rate, 1e18 = 100% APR.
     */
    event NFATHaloAnnualGrowthRateSet(address indexed facility, uint256 annualGrowthRate);

    /**
     * @notice Emitted when an NFAT NFT is issued via this facet.
     * @param  facility Address of the NFAT facility.
     * @param  to       Recipient of the minted NFT (becomes the NFAT owner).
     * @param  tokenId  Identifier of the freshly minted NFAT token.
     * @param  amount   Principal recorded for this token (gem-native decimals).
     */
    event NFATHaloIssue(
        address indexed facility,
        address indexed to,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**
     * @notice Emitted when interest is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount repaid (gem-native decimals).
     */
    event NFATHaloRepayInterest(address indexed facility, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice Emitted when principal is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount repaid (gem-native decimals).
     */
    event NFATHaloRepayPrincipal(address indexed facility, uint256 indexed tokenId, uint256 amount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Issues an NFAT NFT against a prior subscribe and records `amount` as the outstanding
     *         principal for `tokenId`. The facility transfers the gem from itself to its
     *         configured recipient (the controller's ALMProxy).
     * @param  facility Address of the NFAT facility.
     * @param  to       Address to receive the NFT.
     * @param  tokenId  Token id to mint — must be unused on the facility.
     * @param  amount   Principal amount; must equal `to`'s outstanding subscribed deposit.
     */
    function issue(address facility, address to, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays interest against an issued NFAT position. Bounded by `accruedInterest` after
     *         checkpointing; does not touch the principal counter.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount to repay; must be <= currently-accrued interest.
     */
    function repayInterest(address facility, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays principal owed on an issued NFAT position. Bounded by remaining principal
     *         (`principal - principalRepaid`); no rate limit — the principal itself is the bound.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount to repay; must be <= remaining principal.
     */
    function repayPrincipal(address facility, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Sets the annual growth rate (1e18-scaled APR) used for interest accrual on a
     *         facility. Checkpoints the facility before applying the new rate so accrued interest
     *         under the previous rate is preserved.
     * @param  facility         Address of the NFAT facility.
     * @param  annualGrowthRate New annual growth rate, 1e18 = 100% APR.
     */
    function setAnnualGrowthRate(address facility, uint256 annualGrowthRate) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @notice Role required to call `issue`, `repayPrincipal`, and `repayInterest`. Granted to
     *         the off-chain NFAT beacon component that drives issuance and repayment flows.
     */
    function NFAT_BEACON_ROLE() external pure returns (bytes32);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured annual growth rate (1e18-scaled APR) for a facility.
     * @param  facility         Address of the NFAT facility.
     * @return annualGrowthRate Annual growth rate, 1e18 = 100% APR. Zero if unset.
     */
    function getAnnualGrowthRate(address facility) external view returns (uint256 annualGrowthRate);

    /**
     * @notice Returns the total interest currently available to be repaid against a position,
     *         including interest accrued since the last checkpoint.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token.
     * @return amount   Interest available (gem-native decimals).
     */
    function getInterestAvailable(address facility, uint256 tokenId)
        external
        view
        returns (uint256 amount);

    /**
     * @notice Returns the current facility-wide interest index, including time-based accrual
     *         since the last checkpoint.
     * @param  facility      Address of the NFAT facility.
     * @return interestIndex Current cumulative 1e18-scaled interest index.
     */
    function getInterestIndex(address facility) external view returns (uint256 interestIndex);

    /**
     * @notice Returns the full Position record for an NFAT token.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token.
     * @return position The Position record. All fields are zero if unissued.
     */
    function getPosition(address facility, uint256 tokenId)
        external
        view
        returns (Position memory position);

    /**
     * @notice Original principal recorded on `issue` for an NFAT position. Immutable after issue.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token.
     * @return amount   Issued principal in gem-native decimals.
     */
    function getPrincipal(address facility, uint256 tokenId)
        external
        view
        returns (uint256 amount);

    /**
     * @notice Outstanding principal remaining for an NFAT position (`principal - principalRepaid`).
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token.
     * @return amount   Outstanding principal in gem-native decimals.
     */
    function getPrincipalOutstanding(address facility, uint256 tokenId)
        external
        view
        returns (uint256 amount);

    /**
     * @notice Cumulative principal repaid for an NFAT position via `repayPrincipal`.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token.
     * @return amount   Cumulative principal repaid in gem-native decimals.
     */
    function getPrincipalRepaid(address facility, uint256 tokenId)
        external
        view
        returns (uint256 amount);

}
