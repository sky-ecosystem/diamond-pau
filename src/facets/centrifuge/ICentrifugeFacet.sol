// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  ICentrifugeFacet
 * @notice PAU facet for interacting with Centrifuge V3 vaults. Supports cancel, claim-cancel,
 *         and cross-chain share transfers via Centrifuge spokes.
 */
interface ICentrifugeFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when a pending deposit request is cancelled.
     * @param  token Address of the Centrifuge vault token.
     */
    event CentrifugeCancelDepositRequest(address indexed token);

    /**
     * @notice Emitted when a pending redeem request is cancelled.
     * @param  token Address of the Centrifuge vault token.
     */
    event CentrifugeCancelRedeemRequest(address indexed token);

    /**
     * @notice Emitted when assets from a cancelled deposit request are claimed.
     * @param  token Address of the Centrifuge vault token.
     */
    event CentrifugeClaimCancelDepositRequest(address indexed token);

    /**
     * @notice Emitted when shares from a cancelled redeem request are claimed.
     * @param  token Address of the Centrifuge vault token.
     */
    event CentrifugeClaimCancelRedeemRequest(address indexed token);

    /**
     * @notice Emitted when a cross-chain recipient is configured for a centrifuge ID.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     * @param  recipient    Bytes32-encoded recipient address on the destination chain.
     */
    event CentrifugeRecipientSet(uint16 indexed centrifugeId, bytes32 indexed recipient);

    /**
     * @notice Emitted when the transfer rate limit is set.
     * @param  key          Rate limit key.
     * @param  token        Address of the Centrifuge vault token.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     * @param  spoke        Address of the spoke contract.
     */
    event CentrifugeTransferRateLimitSet(
        bytes32 indexed key,
        address indexed token,
        uint16  indexed centrifugeId,
        address         spoke
    );

    /**
     * @notice Emitted when vault shares are transferred cross-chain.
     * @param  token        Address of the Centrifuge vault token.
     * @param  amount       Amount of shares transferred.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     */
    event CentrifugeTransferShares(
        address indexed token,
        uint128         amount,
        uint16  indexed centrifugeId
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Cancels a pending deposit request on a Centrifuge vault.
     * @param  token Address of the Centrifuge vault token.
     */
    function cancelDepositRequest(address token) external;

    /**
     * @notice Cancels a pending redeem request on a Centrifuge vault.
     * @param  token Address of the Centrifuge vault token.
     */
    function cancelRedeemRequest(address token) external;

    /**
     * @notice Claims assets returned from a cancelled deposit request.
     * @param  token Address of the Centrifuge vault token.
     */
    function claimCancelDepositRequest(address token) external;

    /**
     * @notice Claims shares returned from a cancelled redeem request.
     * @param  token Address of the Centrifuge vault token.
     */
    function claimCancelRedeemRequest(address token) external;

    /**
     * @notice Sets the cross-chain recipient for a given centrifuge chain ID.
     * @param  centrifugeId Centrifuge chain identifier.
     * @param  recipient    Bytes32-encoded recipient address.
     */
    function setRecipient(uint16 centrifugeId, bytes32 recipient) external;

    /**
     * @notice Sets the transfer rate limit for a given token, centrifuge ID, and spoke.
     * @param  token        Address of the Centrifuge vault token.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     * @param  spoke        Address of the spoke contract.
     * @param  maxAmount    Maximum amount of the rate limit.
     * @param  slope        Slope of the rate limit.
     * @param  lastAmount   Last amount of the rate limit.
     * @param  lastUpdated  Timestamp of the last update of the rate limit.
     */
    function setTransferRateLimit(
        address token,
        uint16  centrifugeId,
        address spoke,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**
     * @notice Transfers vault shares cross-chain via the Centrifuge spoke.
     * @notice Requires ETH for cross-chain messaging fees (payable).
     * @param  token        Address of the Centrifuge vault token.
     * @param  amount       Amount of shares to transfer.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     */
    function transferShares(address token, uint128 amount, uint16 centrifugeId) external payable;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for deposit operations.
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /// @notice Rate limit key prefix for redeem operations.
    function LIMIT_REDEEM() external pure returns (bytes32);

    /// @notice Rate limit key prefix for cross-chain share transfers.
    function LIMIT_TRANSFER() external pure returns (bytes32);

    /// @notice Centrifuge V3 vault requests are non-fungible and use a fixed request ID of 0.
    function REQUEST_ID() external pure returns (uint256);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured recipient for a centrifuge chain ID.
     * @param  centrifugeId Centrifuge chain identifier.
     * @return recipient    Bytes32-encoded recipient. Zero if not set.
     */
    function getRecipient(uint16 centrifugeId) external view returns (bytes32 recipient);

    /**
     * @notice Returns the transfer rate limit for a given token and centrifuge ID.
     * @param  token        Address of the Centrifuge vault token.
     * @param  centrifugeId Centrifuge chain identifier for the destination.
     * @param  spoke        Address of the spoke contract.
     * @return data         Rate limit data.
     */
    function getTransferRateLimit(address token, uint16 centrifugeId, address spoke)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
