// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacet } from "../IFacet.sol";

/**
 * @title  INFATHaloFacet
 * @notice PAU facet for the Halo (recipient) side of an NFAT facility. Issues NFT positions
 *         against prior subscriptions, accrues per-facility interest via a configurable annual
 *         growth rate, and exposes split repayment flows for principal and interest. Operational
 *         entry points are gated on ALLOCATOR_ROLE and rate-limited per (facility, recipient or
 *         gem) tuple.
 */
interface INFATHaloFacet is IFacet {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Per-facility tunable parameters.
     * @param  annualGrowthRate Annual growth rate (1e18-scaled APR; 1e18 == 100%/year) used to
     *                          drive interest accrual on issued positions.
     */
    struct Parameters {
        uint256 annualGrowthRate;
    }

    /**
     * @notice Per-facility checkpoint state used to compute the cumulative interest index.
     * @param  interestIndex Cumulative 1e18-scaled interest accrued per unit of principal as of
     *                       `lastUpdated`. Combine with elapsed time and the current annual
     *                       growth rate to derive the live index.
     * @param  lastUpdated   Timestamp of the last checkpoint. Zero means the facility has never
     *                       been configured via `setAnnualGrowthRate`.
     */
    struct FacilityState {
        uint256 interestIndex;
        uint256 lastUpdated;
    }

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
     * @param  gem      Address of the facility's gem token at issue time.
     * @param  amount   Principal recorded for this token (gem-native decimals).
     */
    event NFATHaloIssue(
        address indexed facility,
        address indexed to,
        uint256 indexed tokenId,
        address         gem,
        uint256         amount
    );

    /**
     * @notice Emitted when interest is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  gem      Address of the facility's gem token at repay time.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount repaid (gem-native decimals).
     */
    event NFATHaloRepayInterest(
        address indexed facility,
        address indexed gem,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**
     * @notice Emitted when principal is repaid against an issued NFAT position.
     * @param  facility Address of the NFAT facility.
     * @param  gem      Address of the facility's gem token at repay time.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount repaid (gem-native decimals).
     */
    event NFATHaloRepayPrincipal(
        address indexed facility,
        address indexed gem,
        uint256 indexed tokenId,
        uint256         amount
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Issues an NFAT NFT and records the recorded principal for `tokenId`. The facility
     *         transfers the gem from itself to its configured recipient — which MUST be the
     *         controller's ALMProxy, so the principal lands back in our custody. Both the
     *         recorded `principal` and the consumed (facility, to) issue rate limit are sized
     *         from the actual ALMProxy gem balance delta, not the requested `amount`.
     * @param  facility Address of the NFAT facility. Its `recipient()` must equal the ALMProxy.
     * @param  to       Address to receive the NFT.
     * @param  tokenId  Token id to mint — must be unused on the facility.
     * @param  amount   Requested principal to pull from the facility's deposit accounting.
     */
    function issue(address facility, address to, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays interest against an issued NFAT position. Bounded by `accruedInterest` after
     *         checkpointing; consumes the (facility, gem) repay-interest rate limit.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Interest amount to repay. Must be non-zero and <= currently-accrued interest.
     */
    function repayInterest(address facility, uint256 tokenId, uint256 amount) external;

    /**
     * @notice Repays principal owed on an issued NFAT position. Bounded by remaining principal
     *         (`principal - principalRepaid`); consumes the (facility, gem) repay-principal
     *         rate limit.
     * @param  facility Address of the NFAT facility.
     * @param  tokenId  Identifier of the NFAT token being repaid against.
     * @param  amount   Principal amount to repay. Must be non-zero and <= remaining principal.
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
     * @notice Returns the derived issue rate limit key for an NFAT facility, gem, and NFT
     *         recipient.
     * @dev    Keyed on (facility, gem, to) so the budget is scoped per recipient and a facility
     *         cannot change its gem under a configured rate limit; switching the gem invalidates
     *         the key.
     * @param  facility Address of the NFAT facility.
     * @param  gem      Address of the facility's gem token at configuration time.
     * @param  to       Address that will receive issued NFAT NFTs under the configured budget.
     * @return key      Derived rate limit key.
     */
    function getIssueRateLimitKey(address facility, address gem, address to)
        external
        pure
        returns (bytes32 key);

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

    /**
     * @notice Returns the derived repay-interest rate limit key for an NFAT facility and gem.
     * @dev    Keyed on (facility, gem) so a facility cannot change its gem under a configured
     *         rate limit; switching the gem invalidates the key.
     * @param  facility Address of the NFAT facility.
     * @param  gem      Address of the facility's gem token at configuration time.
     * @return key      Derived rate limit key.
     */
    function getRepayInterestRateLimitKey(address facility, address gem)
        external
        pure
        returns (bytes32 key);

    /**
     * @notice Returns the derived repay-principal rate limit key for an NFAT facility and gem.
     * @dev    Keyed on (facility, gem) so a facility cannot change its gem under a configured
     *         rate limit; switching the gem invalidates the key.
     * @param  facility Address of the NFAT facility.
     * @param  gem      Address of the facility's gem token at configuration time.
     * @return key      Derived rate limit key.
     */
    function getRepayPrincipalRateLimitKey(address facility, address gem)
        external
        pure
        returns (bytes32 key);

}
