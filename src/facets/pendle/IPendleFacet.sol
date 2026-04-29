// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IRateLimits } from "../../interfaces/IRateLimits.sol";

import { IFacet } from "../IFacet.sol";

/**
 * @title  IPendleFacet
 * @notice PAU facet for redeeming Pendle PT+YT (PY) tokens back to the underlying yield token after
 *         market expiry.
 */
interface IPendleFacet is IFacet {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice Emitted when PY tokens are redeemed for the underlying yield token.
     * @param  market              Address of the Pendle market.
     * @param  pyAmountIn          Amount of PY tokens redeemed.
     * @param  totalTokenOutAmount Total amount of underlying yield tokens received.
     */
    event PendleRedeem(address indexed market, uint256 pyAmountIn, uint256 totalTokenOutAmount);

    /**
     * @notice Emitted when the redeem rate limit for a Pendle market is updated.
     * @param  key    Derived key of the rate limit.
     * @param  market Address of the Pendle market.
     * @param  pt     Address of the Pendle PT token.
     */
    event PendleRedeemRateLimitSet(bytes32 indexed key, address indexed market, address pt);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Redeems PY tokens for the underlying yield token via the Pendle router.
     * @notice Only works on expired markets.
     * @param  market       Address of the Pendle market.
     * @param  pyAmountIn   Amount of PY tokens to redeem.
     * @param  minAmountOut Minimum underlying yield tokens to receive.
     */
    function redeem(address market, uint256 pyAmountIn, uint256 minAmountOut) external;

    /**
     * @notice Sets the redeem rate limit for a Pendle market.
     * @param  market      Address of the Pendle market.
     * @param  pt          Address of the Pendle PT token.
     * @param  maxAmount   Maximum amount of the rate limit.
     * @param  slope       Slope of the rate limit.
     * @param  lastAmount  Last amount of the rate limit.
     * @param  lastUpdated Timestamp of the last update of the rate limit.
     */
    function setRedeemRateLimit(
        address market,
        address pt,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /// @notice Rate limit key prefix for redeem operations.
    function LIMIT_REDEEM() external pure returns (bytes32);

    /// @notice Address of the Pendle router contract (immutable).
    function router() external view returns (address);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the configured redeem rate limit for a Pendle market.
     * @param  market Address of the Pendle market.
     * @param  pt     Address of the Pendle PT token.
     * @return data   Rate limit data.
     */
    function getRedeemRateLimit(address market, address pt)
        external
        view
        returns (IRateLimits.RateLimitData memory data);

}
