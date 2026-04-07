// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

interface IWEETHFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    event WEETHClaimWithdrawal(
        address indexed weethModule,
        uint256 indexed requestId,
        uint256         ethReceived
    );

    event WEETHDeposit(uint256 amount, uint256 eethAmount, uint256 shares);

    event WEETHRequestWithdraw(
        address indexed weethModule,
        uint256 indexed requestId,
        uint256         eethAmount,
        uint256         weethShares
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @dev    Claims a withdrawal.
     * @param  weethModule Weeth module address.
     * @param  requestId   Request ID.
     * @return ethReceived Amount of ETH received.
     */
    function claimWithdrawal(address weethModule, uint256 requestId)
        external
        returns (uint256 ethReceived);

    /**
     * @dev    Deposits ETH into Weeth.
     * @param  amount       Amount of ETH to deposit.
     * @param  minSharesOut Minimum amount of shares to receive.
     * @return shares       Amount of shares received.
     */
    function deposit(uint256 amount, uint256 minSharesOut) external returns (uint256 shares);

    /**
     * @dev    Requests a withdrawal.
     * @param  weethModule   Weeth module address.
     * @param  weethShares   Amount of weETH shares to withdraw.
     * @param  minEETHShares Minimum amount of eETH shares to receive.
     * @return requestId     Request ID.
     */
    function requestWithdraw(address weethModule, uint256 weethShares, uint256 minEETHShares)
        external
        returns (uint256 requestId);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Limit for deposit operations.
     * @return bytes32 Key for deposit limit.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Limit for request withdrawal operations.
     * @return bytes32 Key for request withdrawal limit.
     */
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    WETH contract address.
     * @return address WETH contract address.
     */
    function weth() external view returns (address);

    /**
     * @dev    Weeth contract address.
     * @return address Weeth contract address.
     */
    function weeth() external view returns (address);

}
