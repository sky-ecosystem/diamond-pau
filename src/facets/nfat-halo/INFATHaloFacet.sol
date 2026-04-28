// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  INFATHaloFacet
 * @notice PAU facet for the Halo (recipient) side of an NFAT facility. Issues NFT positions
 *         against prior subscriptions, tracks per-token principal and repayments in storage,
 *         and exposes two repay paths:
 *
 *           - repayPrincipal: hard-capped by the issued principal (no rate limit). Each call
 *             increments a cumulative `principalRepaid` counter, bounded by `principal`.
 *           - repayInterest:  unbounded by principal, rate-limited per
 *             (facility, NFT owner, tokenId) so each token can carry its own interest budget.
 */
interface INFATHaloFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Per-NFAT bookkeeping recorded by this facet.
     * @param  principal        Amount pulled from the facility on `issue`. Immutable post-issue.
     * @param  principalRepaid  Cumulative principal repaid via `repayPrincipal`; <= principal.
     */
    struct Position {
        uint256 principal;
        uint256 principalRepaid;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when an NFAT NFT is issued via this facet.
     * @param  facility Address of the NFAT facility.
     * @param  to       Recipient of the minted NFT (becomes the rate-limit key holder).
     * @param  tokenId  Identifier of the freshly minted NFAT token.
     * @param  amount   Principal recorded for this token (native gem decimals).
     */
    event NFATIssue(
        address indexed facility,
        address indexed to,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**
     * @notice Emitted when principal is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount repaid (native gem decimals).
     */
    event NFATRepayPrincipal(
        address indexed facility,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**
     * @notice Emitted when interest is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount repaid (native gem decimals).
     */
    event NFATRepayInterest(
        address indexed facility,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Issues an NFAT NFT against a prior subscribe and records `amount` as the
     *         outstanding principal for `tokenId`. The facility transfers the gem from itself
     *         to its configured `recipient` (assumed to be this controller's ALMProxy).
     * @param  facility Address of the NFAT facility.
     * @param  to       Address to receive the NFT (the eventual NFAT owner).
     * @param  tokenId  Token id to mint — must be unused on the facility and non-zero.
     * @param  amount   Principal amount; must equal `to`'s outstanding subscribed deposit.
     */
    function issue(address facility, address to, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays principal owed on an issued NFAT position. Bounded by remaining principal
     *         (`principal - principalRepaid`). No rate limit — the bound is the principal itself.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount to repay; must be <= remaining principal.
     */
    function repayPrincipal(address facility, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays interest against an issued NFAT position. Does not touch the principal
     *         counter; rate-limited per (facility, NFT owner, tokenId).
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount to repay.
     */
    function repayInterest(address facility, uint256 tokenId, uint256 amount) external;

    /**********************************************************************************************/
    /*** External View Functions                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Original principal recorded on `issue` for an NFAT position. Immutable after issue.
     * @param  tokenId Identifier of the NFAT token.
     * @return amount  Issued principal in gem-native decimals.
     */
    function getPrincipal(uint256 tokenId) external view returns (uint256 amount);

    /**
     * @notice Cumulative principal repaid for an NFAT position via `repayPrincipal`.
     * @param  tokenId Identifier of the NFAT token.
     * @return amount  Total principal repaid in gem-native decimals.
     */
    function getPrincipalRepaid(uint256 tokenId) external view returns (uint256 amount);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @notice Rate-limit key for interest repayments, combined with the facility, NFT owner,
     *         and tokenId to form the per-token keys.
     */
    function LIMIT_REPAY_INTEREST() external pure returns (bytes32);

}
