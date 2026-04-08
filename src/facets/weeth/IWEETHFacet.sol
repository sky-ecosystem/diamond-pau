// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IFacetBase } from "../IFacetBase.sol";

/**
 * @title  IWEETHFacet
 * @notice DiamondPAU facet for interacting with EtherFi's weETH. Supports
 *         depositing WETH to receive weETH (via eETH wrapping), requesting
 *         withdrawals back to ETH, and claiming completed withdrawals.
 */
interface IWEETHFacet is IFacetBase {

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev   Emitted when a withdrawal is claimed from a weETH module.
     * @param weethModule Address of the weETH withdrawal module.
     * @param requestId   ID of the withdrawal request being claimed.
     * @param ethReceived Amount of ETH received from the claim.
     */
    event WEETHClaimWithdrawal(
        address indexed weethModule,
        uint256 indexed requestId,
        uint256         ethReceived
    );

    /**
     * @dev   Emitted when WETH is deposited to receive weETH.
     * @param amount     Amount of WETH deposited.
     * @param eethAmount Amount of eETH received (intermediate step).
     * @param shares     Amount of weETH shares received.
     */
    event WEETHDeposit(uint256 amount, uint256 eethAmount, uint256 shares);

    /**
     * @dev   Emitted when an ETH withdrawal is requested from weETH.
     * @param weethModule Address of the weETH withdrawal module.
     * @param requestId   ID of the created withdrawal request.
     * @param eethAmount  Amount of eETH submitted for withdrawal.
     * @param weethShares Amount of weETH shares unwrapped.
     */
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
     * @dev    Claims a completed withdrawal from a weETH module.
     * @param  weethModule Address of the weETH withdrawal module.
     * @param  requestId   ID of the withdrawal request to claim.
     * @return ethReceived Amount of ETH received.
     */
    function claimWithdrawal(address weethModule, uint256 requestId)
        external
        returns (uint256 ethReceived);

    /**
     * @dev    Deposits WETH to receive weETH. Unwraps WETH to ETH, deposits
     *        into EtherFi liquidity pool for eETH, then wraps eETH to weETH.
     * @param  amount       Amount of WETH to deposit.
     * @param  minSharesOut Minimum weETH shares to receive.
     * @return shares       Actual weETH shares received.
     */
    function deposit(uint256 amount, uint256 minSharesOut) external returns (uint256 shares);

    /**
     * @dev    Requests an ETH withdrawal by unwrapping weETH to eETH, then
     *         submitting the eETH to the EtherFi liquidity pool for withdrawal.
     * @param  weethModule   Address of the weETH withdrawal module.
     * @param  weethShares   Amount of weETH shares to withdraw.
     * @param  minEETHShares Minimum eETH shares after unwrapping (slippage check).
     * @return requestId     ID of the created withdrawal request.
     */
    function requestWithdraw(address weethModule, uint256 weethShares, uint256 minEETHShares)
        external
        returns (uint256 requestId);

    /**********************************************************************************************/
    /*** Variables                                                                              ***/
    /**********************************************************************************************/

    /**
     * @dev    Rate limit key for weETH deposit operations.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_DEPOSIT() external pure returns (bytes32);

    /**
     * @dev    Rate limit key for weETH withdrawal request operations, combined
     *         with the weETH module address to form per-module keys.
     * @return bytes32 The rate limit key identifier.
     */
    function LIMIT_REQUEST_WITHDRAW() external pure returns (bytes32);

    /**
     * @dev    Address of the WETH token contract (immutable).
     * @return address The WETH contract address.
     */
    function weth() external view returns (address);

    /**
     * @dev    Address of the weETH token contract (immutable).
     * @return address The weETH contract address.
     */
    function weeth() external view returns (address);

}
