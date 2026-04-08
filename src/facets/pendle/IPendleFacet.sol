// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IPendleFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Event emitted when PY tokens are redeemed.
     * @param market              Pendle market address.
     * @param pyAmountIn          Amount of PY tokens redeemed.
     * @param totalTokenOutAmount Total amount of tokens received.
     */
    event PendleRedeem(address indexed market, uint256 pyAmountIn, uint256 totalTokenOutAmount);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Redeems `pyAmountIn` of PY tokens to `minAmountOut` of tokens.
     * @param market       Pendle market address.
     * @param pyAmountIn   Amount of PY tokens to redeem.
     * @param minAmountOut Minimum amount of tokens to receive.
     */
    function redeem(address market, uint256 pyAmountIn, uint256 minAmountOut) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for redeem operations.
     * @return bytes32 Key for redeem limit.
     */
    function LIMIT_REDEEM() external pure returns (bytes32);

    /**
     * @dev    Pendle router address.
     * @return address Pendle router address.
     */
    function router() external view returns (address);

}
