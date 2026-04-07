// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IERC7540Facet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event ERC7540ClaimDeposit(address indexed token, uint256 shares);

    event ERC7540ClaimRedeem(address indexed token, uint256 assets);

    event ERC7540RequestDeposit(address indexed token, uint256 assets);

    event ERC7540RequestRedeem(address indexed token, uint256 shares);

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev   Claims a deposit request.
     * @param token Token address.
     */
    function claimDeposit(address token) external;

    /**
     * @dev   Claims a redeem request.
     * @param token Token address.
     */
    function claimRedeem(address token) external;

    /**
     * @dev   Requests a deposit.
     * @param token  Token address.
     * @param amount Amount of tokens to deposit.
     */
    function requestDeposit(address token, uint256 amount) external;

    /**
     * @dev   Requests a redeem.
     * @param token  Token address.
     * @param shares Amount of shares to redeem.
     */
    function requestRedeem(address token, uint256 shares) external;

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for redeem operations.
     * @return bytes32 Key for redeem limit.
     */
    function LIMIT_REDEEM() external pure returns (bytes32);

}
